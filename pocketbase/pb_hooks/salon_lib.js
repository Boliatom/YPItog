const SALON_UTC_OFFSET_MIN = 180;
const WEEKDAYS = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"];

function parseDate(value) {
  return new Date(String(value).replace(" ", "T"));
}

function pbDate(date) {
  return date.toISOString().replace("T", " ");
}

function salonLocal(date) {
  return new Date(date.getTime() + SALON_UTC_OFFSET_MIN * 60000);
}

function minutesOf(hhmm) {
  const parts = String(hhmm).split(":");
  return parseInt(parts[0], 10) * 60 + parseInt(parts[1], 10);
}

function totalsFor(app, record) {
  const ids = record.getStringSlice("services");
  let minutes = 0;
  let sum = 0;
  for (let i = 0; i < ids.length; i++) {
    const service = app.findRecordById("services", ids[i]);
    minutes += service.getInt("durationMin");
    sum += service.getFloat("price");
  }
  let discount = 0;
  try {
    const card = app.findFirstRecordByFilter(
      "client_cards",
      "client = {:client}",
      { client: record.getString("client") },
    );
    discount = card.getInt("discountPercent");
  } catch (_) {}
  return { minutes: minutes, sum: sum, discount: discount };
}

function timeOrServicesChanged(record, isCreate) {
  if (isCreate) return true;
  const before = record.original();
  return (
    String(before.get("startsAt")) !== String(record.get("startsAt")) ||
    before.getString("master") !== record.getString("master") ||
    before.getStringSlice("services").join(",") !==
      record.getStringSlice("services").join(",")
  );
}

function checkAppointment(e, isCreate) {
  if (e.hasSuperuserAuth()) return;
  const record = e.record;
  if (!timeOrServicesChanged(record, isCreate)) return;

  const totals = totalsFor(e.app, record);
  const start = parseDate(record.get("startsAt"));
  const end = new Date(start.getTime() + totals.minutes * 60000);
  record.set("endsAt", pbDate(end));
  record.set("discountPercent", totals.discount);
  record.set(
    "totalPrice",
    Math.round((totals.sum * (100 - totals.discount)) / 100),
  );

  if (record.getString("status") === "cancelled") return;

  const master = record.getString("master");
  const startLocal = salonLocal(start);
  const endLocal = salonLocal(end);
  let shift = null;
  try {
    shift = e.app.findFirstRecordByFilter(
      "schedules",
      "master = {:master} && weekday = {:day} && deletedAt = ''",
      { master: master, day: WEEKDAYS[startLocal.getUTCDay()] },
    );
  } catch (_) {}
  if (!shift) {
    throw new ApiError(409, "Мастер не работает в этот день.", {});
  }
  const from = minutesOf(shift.getString("startTime"));
  const to = minutesOf(shift.getString("endTime"));
  const startMin = startLocal.getUTCHours() * 60 + startLocal.getUTCMinutes();
  const endMin = endLocal.getUTCHours() * 60 + endLocal.getUTCMinutes();
  if (startMin < from || endMin > to) {
    throw new ApiError(
      409,
      "Время записи выходит за рабочую смену мастера (" +
        shift.getString("startTime") +
        "–" +
        shift.getString("endTime") +
        ").",
      {},
    );
  }

  const clash = e.app.findRecordsByFilter(
    "appointments",
    "master = {:master} && status != 'cancelled' && deletedAt = '' && id != {:id} && startsAt < {:end} && endsAt > {:start}",
    "",
    1,
    0,
    {
      master: master,
      id: record.id,
      start: pbDate(start),
      end: pbDate(end),
    },
  );
  if (clash.length > 0) {
    throw new ApiError(
      409,
      "Это время у мастера уже занято. Выберите другое время.",
      {},
    );
  }
}

function checkReview(e) {
  if (e.hasSuperuserAuth()) return;
  const appointment = e.app.findRecordById(
    "appointments",
    e.record.getString("appointment"),
  );
  if (
    appointment.getString("status") !== "done" ||
    appointment.getString("client") !== e.record.getString("client")
  ) {
    throw new BadRequestError(
      "Отзыв можно оставить только о своей выполненной записи.",
    );
  }
  e.record.set("master", appointment.getString("master"));
}

function createClientProfile(e) {
  const user = e.record;
  if (user.getString("role") !== "client" || user.getString("client")) return;
  const client = new Record(e.app.findCollectionByNameOrId("clients"));
  client.set("fullName", user.getString("name") || user.getString("email"));
  client.set("phone", "+7 000 000-00-00");
  client.set("email", user.getString("email"));
  e.app.save(client);

  const card = new Record(e.app.findCollectionByNameOrId("client_cards"));
  card.set(
    "number",
    "BS-" + String(900000 + Math.floor(Math.random() * 99999)),
  );
  card.set("client", client.id);
  card.set("discountPercent", 0);
  card.set("bonusPoints", 0);
  card.set("issuedAt", new Date().toISOString().replace("T", " "));
  e.app.save(card);

  user.set("client", client.id);
  e.app.save(user);
}

module.exports = {
  checkAppointment: checkAppointment,
  checkReview: checkReview,
  createClientProfile: createClientProfile,
};

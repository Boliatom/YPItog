onRecordCreateRequest((e) => {
  const lib = require(`${__hooks}/salon_lib.js`);
  lib.checkAppointment(e, true);
  e.next();
}, "appointments");

onRecordUpdateRequest((e) => {
  const lib = require(`${__hooks}/salon_lib.js`);
  lib.checkAppointment(e, false);
  e.next();
}, "appointments");

onRecordCreateRequest((e) => {
  const lib = require(`${__hooks}/salon_lib.js`);
  lib.checkReview(e);
  e.next();
}, "reviews");

onRecordCreateRequest((e) => {
  if (!e.hasSuperuserAuth() || !e.record.getString("role")) {
    e.record.set("role", "client");
  }
  e.next();
}, "users");

onRecordAfterCreateSuccess((e) => {
  const lib = require(`${__hooks}/salon_lib.js`);
  lib.createClientProfile(e);
  e.next();
}, "users");

migrate(
  (app) => {
    const admin = '@request.auth.role = "admin"';
    const authed = '@request.auth.id != ""';

    const autodates = [
      { type: "autodate", name: "created", onCreate: true, onUpdate: false },
      { type: "autodate", name: "updated", onCreate: true, onUpdate: true },
    ];

    const text = (name, extra = {}) =>
      Object.assign({ type: "text", name: name }, extra);
    const int = (name, extra = {}) =>
      Object.assign({ type: "number", name: name, onlyInt: true }, extra);
    const num = (name, extra = {}) =>
      Object.assign({ type: "number", name: name }, extra);
    const date = (name, extra = {}) =>
      Object.assign({ type: "date", name: name }, extra);
    const select = (name, values, extra = {}) =>
      Object.assign(
        { type: "select", name: name, values: values, maxSelect: 1 },
        extra,
      );
    const rel = (name, collection, extra = {}) =>
      Object.assign(
        {
          type: "relation",
          name: name,
          collectionId: app.findCollectionByNameOrId(collection).id,
          cascadeDelete: false,
          maxSelect: 1,
        },
        extra,
      );
    const rels = (name, collection, extra = {}) =>
      rel(name, collection, Object.assign({ maxSelect: 100 }, extra));

    const make = (name, fields, rules, indexes = []) => {
      const collection = new Collection(
        Object.assign(
          {
            type: "base",
            name: name,
            fields: fields.concat([date("deletedAt")], autodates),
            indexes: indexes,
          },
          rules,
        ),
      );
      app.save(collection);
    };

    const readAll = { listRule: authed, viewRule: authed };
    const writeAdmin = {
      createRule: admin,
      updateRule: admin,
      deleteRule: admin,
    };

    make(
      "service_categories",
      [
        text("name", { required: true, min: 2, max: 60 }),
        text("description", { max: 300 }),
      ],
      Object.assign({}, readAll, writeAdmin),
      ["CREATE UNIQUE INDEX idx_categories_name ON service_categories (name)"],
    );

    make(
      "services",
      [
        text("name", { required: true, min: 2, max: 80 }),
        rel("category", "service_categories", { required: true }),
        int("durationMin", { required: true, min: 5, max: 480 }),
        num("price", { required: true, min: 1, max: 100000 }),
        text("description", { max: 500 }),
        { type: "bool", name: "active" },
      ],
      Object.assign({}, readAll, writeAdmin),
      ["CREATE UNIQUE INDEX idx_services_name ON services (name)"],
    );

    make(
      "masters",
      [
        text("fullName", { required: true, min: 2, max: 80 }),
        select(
          "position",
          ["hairdresser", "nails", "cosmetologist", "brows", "massage"],
          { required: true },
        ),
        text("phone", { required: true, pattern: "^\\+?[0-9\\s\\-()]{7,20}$" }),
        int("experienceYears", { min: 0, max: 60 }),
        rels("services", "services", { required: true }),
        text("bio", { max: 500 }),
      ],
      Object.assign({}, readAll, writeAdmin),
    );

    make(
      "clients",
      [
        text("fullName", { required: true, min: 2, max: 80 }),
        text("phone", { required: true, pattern: "^\\+?[0-9\\s\\-()]{7,20}$" }),
        { type: "email", name: "email" },
        date("birthDate"),
        text("notes", { max: 300 }),
      ],
      {
        listRule:
          '@request.auth.role = "admin" || @request.auth.role = "master" || id = @request.auth.client',
        viewRule:
          '@request.auth.role = "admin" || @request.auth.role = "master" || id = @request.auth.client',
        createRule: admin,
        updateRule: admin + " || id = @request.auth.client",
        deleteRule: admin,
      },
    );

    make(
      "client_cards",
      [
        text("number", { required: true, pattern: "^BS-\\d{6}$" }),
        rel("client", "clients", { required: true }),
        int("discountPercent", { min: 0, max: 30 }),
        int("bonusPoints", { min: 0, max: 1000000 }),
        date("issuedAt", { required: true }),
      ],
      Object.assign(
        {
          listRule: admin + " || client = @request.auth.client",
          viewRule: admin + " || client = @request.auth.client",
        },
        writeAdmin,
      ),
      [
        "CREATE UNIQUE INDEX idx_cards_number ON client_cards (number)",
        "CREATE UNIQUE INDEX idx_cards_client ON client_cards (client)",
      ],
    );

    make(
      "schedules",
      [
        rel("master", "masters", { required: true }),
        select("weekday", ["mon", "tue", "wed", "thu", "fri", "sat", "sun"], {
          required: true,
        }),
        text("startTime", {
          required: true,
          pattern: "^([01]\\d|2[0-3]):[0-5]\\d$",
        }),
        text("endTime", {
          required: true,
          pattern: "^([01]\\d|2[0-3]):[0-5]\\d$",
        }),
      ],
      Object.assign({}, readAll, writeAdmin),
      [
        "CREATE UNIQUE INDEX idx_schedules_master_day ON schedules (master, weekday)",
      ],
    );

    const own = admin + " || client = @request.auth.client || master = @request.auth.master";
    make(
      "appointments",
      [
        rel("client", "clients", { required: true }),
        rel("master", "masters", { required: true }),
        rels("services", "services", { required: true }),
        date("startsAt", { required: true }),
        date("endsAt", { required: true }),
        select("status", ["new", "confirmed", "done", "cancelled"], {
          required: true,
        }),
        int("discountPercent", { min: 0, max: 100 }),
        num("totalPrice", { min: 0 }),
        text("comment", { max: 300 }),
      ],
      {
        listRule: own,
        viewRule: own,
        createRule:
          admin +
          ' || (@request.auth.role = "client" && @request.body.client = @request.auth.client)',
        updateRule:
          admin +
          ' || (@request.auth.role = "master" && master = @request.auth.master)' +
          ' || (client = @request.auth.client && @request.body.status = "cancelled")',
        deleteRule: admin,
      },
      [
        "CREATE INDEX idx_appointments_master_start ON appointments (master, startsAt)",
      ],
    );

    make(
      "reviews",
      [
        rel("appointment", "appointments", { required: true }),
        rel("client", "clients", { required: true }),
        rel("master", "masters", { required: true }),
        int("rating", { required: true, min: 1, max: 5 }),
        text("text", { max: 500 }),
      ],
      Object.assign({}, readAll, {
        createRule:
          '@request.auth.role = "client" && @request.body.client = @request.auth.client',
        updateRule: admin,
        deleteRule: admin,
      }),
      ["CREATE UNIQUE INDEX idx_reviews_appointment ON reviews (appointment)"],
    );

    const busy = new Collection({
      type: "view",
      name: "busy_slots",
      listRule: authed,
      viewRule: authed,
      viewQuery:
        "SELECT id, master, startsAt, endsAt FROM appointments WHERE status != 'cancelled' AND deletedAt = ''",
    });
    app.save(busy);

    const users = app.findCollectionByNameOrId("users");
    users.fields.add(
      new SelectField({
        name: "role",
        values: ["client", "master", "admin"],
        maxSelect: 1,
      }),
    );
    users.fields.add(
      new RelationField({
        name: "client",
        collectionId: app.findCollectionByNameOrId("clients").id,
        maxSelect: 1,
        cascadeDelete: false,
      }),
    );
    users.fields.add(
      new RelationField({
        name: "master",
        collectionId: app.findCollectionByNameOrId("masters").id,
        maxSelect: 1,
        cascadeDelete: false,
      }),
    );
    users.listRule = admin + " || id = @request.auth.id";
    users.viewRule = admin + " || id = @request.auth.id";
    users.createRule = "@request.body.role:isset = false";
    users.updateRule =
      admin + " || (id = @request.auth.id && @request.body.role:isset = false)";
    users.deleteRule = admin;
    users.authToken.duration = 900;
    app.save(users);
  },
  (app) => {
    for (const name of [
      "busy_slots",
      "reviews",
      "appointments",
      "schedules",
      "client_cards",
      "clients",
      "masters",
      "services",
      "service_categories",
    ]) {
      try {
        app.delete(app.findCollectionByNameOrId(name));
      } catch (_) {}
    }
  },
);

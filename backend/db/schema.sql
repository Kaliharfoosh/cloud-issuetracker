-- Lab 5: run this in the Neon SQL Editor against the database in DATABASE_URL.
-- Each column matches a field in the Lab 3 data dictionary. The server still owns
-- id, status and the creation time: the database fills them in with DEFAULT.
-- The CHECK rules repeat the controller's validation inside the database, so even a
-- bug in the API cannot store an invalid priority or status.

CREATE TABLE issues (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title       VARCHAR(100) NOT NULL,
    description VARCHAR(500) NOT NULL,
    priority    TEXT NOT NULL CHECK (priority IN ('Low', 'Medium', 'High')),
    status      TEXT NOT NULL DEFAULT 'Open' CHECK (status IN ('Open', 'Resolved')),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS users (
    id text PRIMARY KEY,
    email text NOT NULL UNIQUE,
    password_hash text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS sessions (
    token_hash text PRIMARY KEY,
    user_id text NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    expires_at timestamptz NOT NULL,
    verified_at timestamptz
);
CREATE INDEX IF NOT EXISTS sessions_user ON sessions(user_id);
CREATE TABLE IF NOT EXISTS documents (
    user_id text NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    path text NOT NULL,
    collection text NOT NULL,
    data jsonb NOT NULL CHECK (jsonb_typeof(data) = 'object'),
    PRIMARY KEY (user_id, path)
);
CREATE INDEX IF NOT EXISTS documents_collection ON documents(user_id, collection, path);
CREATE INDEX IF NOT EXISTS documents_date ON documents(user_id, collection, (data->'date'->>'value'), path);
CREATE INDEX IF NOT EXISTS documents_type ON documents(user_id, collection, (data->>'type'));
CREATE INDEX IF NOT EXISTS documents_fields ON documents USING gin(data);
CREATE TABLE IF NOT EXISTS requests (
    user_id text NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    id text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, id)
);
CREATE TABLE IF NOT EXISTS rate_limits (
    key text PRIMARY KEY,
    count integer NOT NULL DEFAULT 1,
    expires_at timestamptz NOT NULL
);
-- Authentication secrets are separate from user documents and CSV exports.
CREATE TABLE IF NOT EXISTS mfa (
    user_id text PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    secret text,
    pending_secret text,
    pending_expires_at timestamptz,
    last_counter bigint NOT NULL DEFAULT -1
);
CREATE TABLE IF NOT EXISTS mfa_recovery (
    user_id text NOT NULL REFERENCES mfa(user_id) ON DELETE CASCADE,
    code_hash text NOT NULL,
    PRIMARY KEY (user_id, code_hash)
);
CREATE TABLE IF NOT EXISTS mfa_challenges (
    token_hash text PRIMARY KEY,
    user_id text NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    expires_at timestamptz NOT NULL
);
CREATE INDEX IF NOT EXISTS mfa_challenges_user ON mfa_challenges(user_id);

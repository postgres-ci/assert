drop schema if exists example_auth cascade;

create schema example_auth;

create table example_auth.users(
    user_id serial primary key,
    login varchar  not null,
    hash  char(64) not null,
    salt  char(64) not null
);

create unique index u_idx_login on example_auth.users(lower(login));

create or replace function example_auth.hash() returns char(64) as $$
    begin
        return encode(digest(gen_salt('md5') || clock_timestamp(), 'sha256'), 'hex');
    end;
$$ language plpgsql;

create unlogged table example_auth.sessions(
    session_id char(64) not null default example_auth.hash() primary key,
    user_id    int not null references example_auth.users(user_id),
    expires_at timestamp with time zone not null
);

create index idx_session_expires_at on example_auth.sessions (expires_at);

create function example_auth.login(_login varchar, _password varchar, out session_id varchar) returns varchar as $$
declare
        _user_id          int;
        _invalid_password boolean;
    begin

        SELECT
            U.user_id,
            encode(digest(U.salt || _password, 'sha256'), 'hex') != U.hash
            INTO
                _user_id,
                _invalid_password
        FROM example_auth.users AS U
        WHERE lower(U.login) = lower(_login);

        IF NOT FOUND THEN
            RAISE EXCEPTION 'NOT_FOUND';
        END IF;

        IF _invalid_password THEN
            RAISE EXCEPTION 'INVALID_PASSWORD';
        END IF;

        INSERT INTO example_auth.sessions (
            user_id,
            expires_at
        ) VALUES (
            _user_id,
            CURRENT_TIMESTAMP + '1 hour'::interval
        ) RETURNING example_auth.sessions.session_id INTO session_id;

    end;
$$ language plpgsql;


create function example_auth.get_auth_user(
    _session_id char,
    out user_id int,
    out login   varchar
) returns record as $$
    begin

        SELECT
            U.user_id,
            U.login
                INTO
                    user_id,
                    login
        FROM example_auth.users AS U
        JOIN example_auth.sessions AS S USING(user_id)
        WHERE S.session_id = _session_id
        AND   S.expires_at > CURRENT_TIMESTAMP;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'NOT_FOUND';
        END IF;

        UPDATE example_auth.sessions SET expires_at = CURRENT_TIMESTAMP + '1 hour'::interval WHERE session_id = _session_id;

    end;
$$ language plpgsql;


create function example_auth.init_admin(
    out login  varchar,
    out password varchar
) returns record as $$
    declare
        _salt char(64) = example_auth.hash();
    begin

        login    = 'admin';
        password = 'password';

        INSERT INTO example_auth.users (
            login,
            hash,
            salt
        ) VALUES (
            login,
            encode(digest(_salt || password, 'sha256'), 'hex'),
            _salt
        );

    end;
$$ language plpgsql;

select example_auth.init_admin();

create or replace function example_auth.TestHash() returns void as $$
    declare
        _hash   char(64);
        _hashes char(64)[] default '{}';
    begin

        FOR i IN 1..1000 LOOP

            _hash = example_auth.hash();

            IF NOT (assert.Equal(char_length(_hash), 64, 'Check hash length') AND assert.False(_hashes @> ARRAY[_hash])) THEN
                EXIT;
            END IF;

            _hashes = array_append(_hashes, _hash);

        END LOOP;

    end;
$$ language plpgsql;

create or replace function example_auth.TestLogin() returns void as $$
    declare
        _query text;
    begin

        _query = 'SELECT * FROM example_auth.login(''not'', ''found'')';

        IF assert.Exception(_query, 'NOT_FOUND') THEN

            _query = 'SELECT * FROM example_auth.login(''admin'', ''ip'')';

            IF assert.Exception(_query, 'INVALID_PASSWORD') THEN

                PERFORM assert.Equal('admin', login) FROM example_auth.get_auth_user(
                    example_auth.login('admin', 'password')
                );

            END IF;

        END IF;

    end;
$$ language plpgsql;

insert into assert.tests (test_func) values ('example_auth.TestHash'), ('example_auth.TestLogin') on conflict do nothing;

select * from assert.TestRunner() \x

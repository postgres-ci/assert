create or replace function example.test_create_user() returns void as $$
    declare
        _user_id       int;
        _user_name     varchar;
        _current_count int;
    begin 

        SELECT COUNT(*) INTO _current_count FROM example.users;

        INSERT INTO example.users (user_name) 
            SELECT 'user_name_' || U::varchar FROM generate_series(1, 100) AS U;

        IF assert.equal(_current_count + 100, (select count(*)::int from example.users)) THEN 

            _user_name = 'user_name_' || random()*1000;

            _user_id   = example.create_user(_user_name);

            IF assert.not_null(_user_id, 'Retuning value should be integer') THEN

                PERFORM example.create_user('TxUserName');

                IF assert.equal(_current_count + 102, (select count(*)::int from example.users)) THEN 

                    PERFORM assert.equal(_user_name, (select user_name from example.users where user_id = _user_id));
                END IF;
            END IF;
        END IF;
    end;
$$ language plpgsql;

create or replace function example.test_roll_back_a_transaction_for_each_test() returns void as $$
    -- The framework will create and roll back a transaction for each test.
    begin 

        IF assert.true(NOT EXISTS(SELECT FROM example.users WHERE user_name = 'TxUserName'), 'The user should not be present in db') THEN 

           IF assert.not_null(example.create_user('TxUserName'), 'Retuning value should be integer') THEN 

                PERFORM assert.false(
                    NOT EXISTS(SELECT FROM example.users WHERE user_name = 'TxUserName'), 
                    'The user should be present in db'
                );

           END IF;

        END IF;

    end;
$$ language plpgsql;

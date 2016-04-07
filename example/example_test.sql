create or replace function example.test_create_user() returns void as $$
    declare
        _user_id   int;
        _user_name varchar;
    begin 
        IF assert.equal(100, (select count(*)::int from example.users)) THEN 

            _user_name = 'user_name_' || random()*1000;

            _user_id   = example.create_user(_user_name);

            PERFORM example.create_user('TxUserName');

            IF assert.equal(102, (select count(*)::int from example.users)) THEN 

                PERFORM assert.equal(_user_name, (select user_name from example.users where user_id = _user_id));
            END IF;

        END IF;
    end;
$$ language plpgsql;


create or replace function example.test_roll_back_a_transaction_for_each_test() returns void as $$
    -- The framework will create and roll back a transaction for each test.
    begin 

        IF assert.false(EXISTS(SELECT FROM example.users WHERE user_name = 'TxUserName'), 'The user should not be present in db') THEN 
            return;
        END IF;

        PERFORM example.create_user('TxUserName');
    end;
$$ language plpgsql;

select assert.add_test('example', 'test_create_user');
select assert.add_test('example', 'test_roll_back_a_transaction_for_each_test');

select 
    namespace || '.' || procedure as func,
    case 
        when array_length(errors, 1) is null 
        then 'pass'
        else 'fail' 
    end 
    as result,
    to_json(errors) as errors,
    finished_at - started_at as duration
from  assert.test_runner();

/*

create or replace function example.test_func() returns void as $$
    begin 
        IF assert.equal(2, 2) THEN 
            PERFORM assert.equal(1, 42);
        END IF;
    end;
$$ language plpgsql;


create or replace function example.test_func2() returns void as $$
    begin 
        IF assert.equal(2, 2) THEN 
            PERFORM assert.equal(42, 42);
        END IF;
    end;
$$ language plpgsql;

*/


-- select assert.add_test('example', 'test_func');
-- select assert.add_test('example', 'test_func2');

/*


-[ RECORD 1 ]--------------------------------------------------------------------------------
func     | example.test_func
result   | fail
errors   | [{"message":"Not equal: 1 (expected) != 42 (actual)","comment":""}]
duration | 00:00:00.000757
-[ RECORD 2 ]--------------------------------------------------------------------------------
func     | example.test_func2
result   | pass
errors   | []
duration | 00:00:00.000363


*/
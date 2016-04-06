create or replace function example.test_create_user() returns void as $$
    declare
        _user_id   int;
        _user_name varchar;
    begin 
        IF assert.equal(100, (select count(*)::int from example.users)) THEN 

            _user_name = 'user_name_' || random()*1000;

            _user_id   = example.create_user(_user_name);

            IF assert.equal(101, (select count(*)::int from example.users)) THEN 

                PERFORM assert.equal(_user_name, (select user_name from example.users where user_id = _user_id));
            END IF;

        END IF;
    end;
$$ language plpgsql;


select assert.add_test('example', 'test_create_user');

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


-[ RECORD 1 ]----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
func     | example.test_func
result   | fail
errors   | [{"message":"Not equal: 1 (expected) != 42 (actual)","comment":"","context":"PL/pgSQL function assert.equal(anyelement,anyelement,text) line 8 at GET DIAGNOSTICS\nSQL statement \"SELECT assert.equal(1, 42)\"\nPL/pgSQL function example.test_func() line 4 at PERFORM\nSQL statement \"SELECT example.test_func()\"\nPL/pgSQL function assert.test_runner() line 24 at EXECUTE"}]
duration | 00:00:00.000757
-[ RECORD 2 ]----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
func     | example.test_func2
result   | pass
errors   | []
duration | 00:00:00.000363


*/
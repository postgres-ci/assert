create schema example;

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
            PERFORM assert.equal(1, 1);
        END IF;
    end;
$$ language plpgsql;


select assert.add_test('example', 'test_func');
select assert.add_test('example', 'test_func2');

select 
    namespace || '.' || procedure as  func,
    case 
        when array_length(errors, 1) is null 
        then 'pass'
        else 'fail' end 
    as result,
    to_json(errors) as errors,
    finished_at - started_at AS duration
from  assert.test_runner();

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
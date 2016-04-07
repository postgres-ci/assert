create or replace function assert.not_null(_value anyelement, _comment text default '') returns boolean as $$
    begin
        return true;
    end;
$$ language plpgsql security definer;

create or replace function assert.not_null(_value text, _comment text default '') returns boolean as $$
    begin

        IF _value IS NULL THEN
            return assert.fail('Expected value not to be null.', _comment);
        END if;

        return true;
    end;
$$ language plpgsql security definer;
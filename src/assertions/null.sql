create or replace function assert.null(_value anyelement, _comment text default '') returns boolean as $$
    begin

        IF _value IS NOT NULL THEN
            return assert.fail(format('Expected null, but got: %s', _value), _comment);
        END if;

        return true;
    end;
$$ language plpgsql security definer;

create or replace function assert.null(_value text, _comment text default '') returns boolean as $$
    begin

        IF _value IS NOT NULL THEN
            return assert.fail(format('Expected null, but got: %s', _value), _comment);
        END if;

        return true;
    end;
$$ language plpgsql security definer;
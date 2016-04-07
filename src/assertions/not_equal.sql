create or replace function assert.not_equal(_expected anyelement, _actual anyelement, _comment text default '') returns boolean as $$
    begin

        IF _expected = _actual THEN
            return assert.fail(format('Should not be: %s', _actual), _comment);
        END IF;

        return true;
    end;
$$ language plpgsql security definer;

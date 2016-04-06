grant  usage   on schema assert to public;
revoke execute on all functions in schema assert from public;
grant execute on function assert.add_test(name, name) to public;
grant execute on function assert.test_runner() to public;
grant execute on function assert.equal(anyelement, anyelement, text) to public;
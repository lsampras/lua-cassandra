local log = require "cassandra.log"
local cassandra = require "cassandra"

describe("Casandra", function()
  local p = log.print
  setup(function()
    spy.on(log, "set_lvl")
    local l = mock(log.print, true)
    log.print = l
  end)
  teardown(function()
    log.set_lvl:revert()
    log.print = p
  end)
  it("should have a default logging level", function()
    local lvl = log.get_lvl()
    assert.equal(0, lvl)
  end)
  describe("set_log_level", function()
    it("should set the logging level when outside of ngx_lua", function()
      finally(function()
        log.print:clear()
      end)

      cassandra.set_log_level("INFO")
      assert.spy(log.set_lvl).was.called_with("INFO")

      -- INFO
      log.err("hello world")
      log.info("hello world")
      assert.spy(log.print).was.called(2)

      log.print:clear()
      cassandra.set_log_level("ERR")

      -- ERR
      log.err("bye world")
      log.info("bye world")
      assert.spy(log.print).was.called(1)
    end)
    pending("should have a default format", function()
      finally(function()
        log.print:clear()
      end)
      log.err("hello")
      assert.spy(log.print).was.called_with("ERR -- hello")
    end)
  end)
  describe("set_log_format", function()
    it("should set the logging format when outside of ngx_lua", function()
      finally(function()
        log.print:clear()
      end)

      cassandra.set_log_format("Cassandra [%s]: %s")
      log.err("some error")
      assert.spy(log.print).was.called_with("Cassandra [ERR]: some error")
    end)
  end)
  describe("consistencies", function()
    it("should have Cassandra data consistency values available", function()
      assert.truthy(cassandra.consistencies)

      local types = require "cassandra.types"
      for t in pairs(types.consistencies) do
        assert.truthy(cassandra.consistencies[t])
      end
    end)
  end)
  describe("cql_errors", function()
    it("should have Cassandra CQL error types values available", function()
      assert.truthy(cassandra.cql_errors)

      local types = require "cassandra.types"
      for t in pairs(types.ERRORS) do
        assert.truthy(cassandra.cql_errors[t])
      end
    end)
  end)
  describe("shorthand serializers", function()
    it("should require the first argument (value)", function()
      assert.has_error(cassandra.uuid, "argument #1 required for 'uuid' type shorthand")
      assert.has_error(cassandra.map, "argument #1 required for 'map' type shorthand")
      assert.has_error(cassandra.list, "argument #1 required for 'list' type shorthand")
      assert.has_error(cassandra.timestamp, "argument #1 required for 'timestamp' type shorthand")
      local trace = debug.traceback()
      local match = string.find(trace, "stack traceback:\n\tspec/01-unit/cassandra_spec.lua", nil, true)
      assert.equal(1, match)
    end)
  end)
end)
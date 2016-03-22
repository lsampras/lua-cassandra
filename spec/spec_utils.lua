local unpack = rawget(table, "unpack") or unpack

local function exec(cmd, ignore)
  local res1 = os.execute(cmd.." >/dev/null")
  local ok
  if _VERSION == "Lua 5.1" then
    ok = res1 == 0
  else
    ok = not not res1
  end
  if not ok and not ignore then
    error("non-0 exit code: "..cmd, 2)
    os.exit(1)
  end
  return ok
end

local _M = {
  cassandra_version = os.getenv("CASSANDRA") or "2.1.12",
  ssl_path = os.getenv("SSL_PATH") or "spec/fixtures/ssl"
}

--- CCM

local function ccm_exists(c_name)
  return exec("ccm list | grep "..c_name, true)
end

local function ccm_is_current(c_name)
  return exec("ccm list | grep '*"..c_name.."'", true)
end

function _M.ccm_start(n_nodes, opts)
  n_nodes = n_nodes or 3
  opts = opts or {}
  opts.name = opts.name or "default"
  opts.version = opts.version or _M.cassandra_version

  local cluster_name = "lua_cassandra_"..opts.name.."_specs"

  if not ccm_is_current(cluster_name) then
    exec("ccm stop", true)
  end

  -- create cluster if not exists
  if not ccm_exists(cluster_name) then
    local cmd = string.format("ccm create %s -v binary:%s -n %s",
                              cluster_name, opts.version, n_nodes)
    if opts.ssl then
      cmd = cmd.." --ssl='".._M.ssl_path.."'"
    end
    if opts.require_client_auth then
      cmd = cmd.." --require_client_auth"
    end
    if opts.pwd_auth then
      cmd = cmd.." --pwd-auth"
    end

    exec(cmd)
  end

  exec("ccm switch "..cluster_name)
  exec("ccm start --wait-for-binary-proto")

  local hosts = {}
  for i = 1, n_nodes do
    hosts[#hosts+1] = "127.0.0."..i
  end

  if opts.pwd_auth then
    -- the cassandra superuser takes some time to be created
    os.execute "sleep 5"
  end

  return hosts
end

function _M.ccm_down_node(node_n)
  assert(type(node_n) == "number")
  exec("ccm node"..node_n.." pause")
end

function _M.ccm_up_node(node_n)
  assert(type(node_n) == "number")
  exec("ccm node"..node_n.." resume")
end

function _M.ccm_restart_node(node_n)
  assert(type(node_n) == "number")
  exec("ccm node"..node_n.." stop")
  exec("ccm node"..node_n.." start --wait-for-binary-proto")
end

--- CQL

function _M.create_keyspace(host, keyspace)
  return host:execute([[
    CREATE KEYSPACE IF NOT EXISTS ]]..keyspace..[[
    WITH REPLICATION = {'class': 'SimpleStrategy', 'replication_factor': 1}
  ]])
end

function _M.drop_keyspace(host, keyspace)
  return host:execute("DROP KEYSPACE "..keyspace)
end

--- Assertions

local say = require "say"
local assert = require "luassert.assert"

local delta = 0.0000001
local function fixture(state, arguments)
  local ok
  local fixture_type, fixture, decoded = unpack(arguments)
  if fixture_type == "float" then
    ok = math.abs(decoded - fixture) < delta
  elseif type(fixture) == "table" then
    ok = pcall(assert.same, fixture, decoded)
  else
    ok = pcall(assert.equal, fixture, decoded)
  end
  -- pop first argument, for proper output message (like assert.same)
  table.remove(arguments, 1)
  table.insert(arguments, 1, table.remove(arguments, 2))
  return ok
end

local function same_set(state, arguments)
  local fixture, decoded = unpack(arguments)

  for _, x in ipairs(fixture) do
    local has = false
    for _, y in ipairs(decoded) do
      if y == x then
        has = true
        break
      end
    end
    if not has then
      return false
    end
  end

  return true
end

say:set("assertion.same_set.positive", "Fixture and decoded value do not match")
say:set("assertion.same_set.negative", "Fixture and decoded value do not match")
assert:register("assertion", "same_set", same_set,
                "assertion.same_set.positive",
                "assertion.same_set.negative")

say:set("assertion.fixture.positive",
        "Expected fixture and decoded value to match.\nPassed in:\n%s\nExpected:\n%s")
say:set("assertion.fixture.negative",
        "Expected fixture and decoded value to not match.\nPassed in:\n%s\nExpected:\n%s")
assert:register("assertion", "fixture", fixture,
                "assertion.fixture.positive",
                "assertion.fixture.negative")

--- Fixtures

local types = require "cassandra.types"

_M.cql_fixtures = {
  -- custom
  ascii = {"Hello world", ""},
  bigint = {0, 42, -42, 42000000000, -42000000000},
  boolean = {true, false},
  -- counter
  double = {0, 1.0000000000000004, -1.0000000000000004},
  float = {0, 3.14151, -3.14151},
  inet = {
    "127.0.0.1", "0.0.0.1", "8.8.8.8",
    "2001:0db8:85a3:0042:1000:8a2e:0370:7334",
    "2001:0db8:0000:0000:0000:0000:0000:0001"
  },
  int = {0, 4200, -42},
  text = {"Hello world", ""},
  -- list
  -- map
  -- set
  -- uuid
  timestamp = {1405356926},
  varchar = {"Hello world", ""},
  varint = {0, 4200, -42},
  timeuuid = {"1144bada-852c-11e3-89fb-e0b9a54a6d11"}
  -- udt
  -- tuple
}

_M.cql_list_fixtures = {
  {value_type = types.cql_types.text, type_name = "text", value = {"abc", "def"}},
  {value_type = types.cql_types.int, type_name = "int", value = {1, 2 , 0, -42, 42}}
}

_M.cql_set_fixtures = _M.cql_list_fixture

_M.cql_map_fixtures = {
  {
   key_type = types.cql_types.text,
   key_type_name = "text",
   value_type = types.cql_types.text,
   value_type_name = "text",
   value = {k1 = "v1", k2 = "v2"}
  },
  {
   key_type = types.cql_types.text,
   key_type_name = "text",
   value_type = types.cql_types.int,
   value_type_name = "int",
   value = {k1 = 1, k2 = 2}
  }
}

_M.cql_tuple_fixtures = {
  {type = {"text", "text"}, value = {"hello", "world"}},
  {type = {"text", "text"}, value = {"world", "hello"}}
}

_M.keyspace = "lua_resty_specs"

return _M

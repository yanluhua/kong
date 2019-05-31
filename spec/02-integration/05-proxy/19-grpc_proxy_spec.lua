local helpers = require "spec.helpers"


for _, strategy in helpers.each_strategy() do

  describe("gRPC Proxying [#" .. strategy .. "]", function()
    local proxy_client_grpc
    local proxy_client_grpcs
    local proxy_client
    local proxy_client_ssl
    local proxy_client_h2c
    local proxy_client_h2

    lazy_setup(function()
      local bp = helpers.get_db_utils(strategy, {
        "routes",
        "services",
      })

      local service1 = assert(bp.services:insert {
        name = "grpc",
        url = "grpc://localhost:15002",
      })

      local service2 = assert(bp.services:insert {
        name = "grpcs",
        url = "grpcs://localhost:15003",
      })

      assert(bp.routes:insert {
        protocols = { "grpc" },
        hosts = { "grpc" },
        service = service1,
      })

      assert(bp.routes:insert {
        protocols = { "grpcs" },
        hosts = { "grpcs" },
        service = service2,
      })

      assert(helpers.start_kong {
        database = strategy,
      })

      proxy_client_grpc = helpers.proxy_client_grpc()
      proxy_client_grpcs = helpers.proxy_client_grpcs()
      proxy_client_h2c = helpers.proxy_client_h2c()
      proxy_client_h2 = helpers.proxy_client_h2()
      proxy_client = helpers.proxy_client()
      proxy_client_ssl = helpers.proxy_ssl_client()
    end)

    lazy_teardown(function()
      helpers.stop_kong()
    end)

    describe("proxies", function()
      it("grpc", function()
        local ok, resp = proxy_client_grpc({
          service = "hello.HelloService.SayHello",
          body = {
            greeting = "world!"
          },
          opts = {
            ["-authority"] = "grpc",
          }
        })
        assert.truthy(ok)
        assert.truthy(resp)
      end)

      it("grpcs", function()
        local ok, resp = proxy_client_grpcs({
          service = "hello.HelloService.SayHello",
          body = {
            greeting = "world!"
          },
          opts = {
            ["-authority"] = "grpcs",
          }
        })
        assert.truthy(ok)
        assert.truthy(resp)
      end)
    end)

    describe("errors with", function()
      it("non-http2 request on grpc route", function()
        local res = assert(proxy_client:post("/", {
          headers = {
            ["Host"] = "grpc",
            ["Content-Type"] = "application/grpc"
          }
        }))
        local body = assert.res_status(426, res)
        assert.same('{"message":"Please use HTTP2 protocol"}', body)
        assert.contains("Upgrade", res.headers.connection)
        assert.same("HTTP/2", res.headers["upgrade"])
      end)

      it("non-http2 request on grpcs route", function()
        local res = assert(proxy_client_ssl:post("/", {
          headers = {
            ["Host"] = "grpcs",
            ["Content-Type"] = "application/grpc"
          }
        }))
        local body = assert.res_status(426, res)
        assert.same('{"message":"Please use HTTP2 protocol"}', body)
      end)

      it("non-grpc request on grpc route (no content-type)", function()
        local body, headers = proxy_client_h2c({
          headers = {
            ["method"] = "POST",
            [":authority"] = "grpc",
          }
        })
        assert.same("415", headers:get(":status"))
        assert.same('{"message":"Non-gRPC request matched gRPC route"}', body)
      end)

      it("non-grpc request on grpcs route (no content-type)", function()
        local body, headers = proxy_client_h2({
          headers = {
            ["method"] = "POST",
            [":authority"] = "grpcs",
          }
        })
        assert.same("415", headers:get(":status"))
        assert.same('{"message":"Non-gRPC request matched gRPC route"}', body)
      end)

      it("non-grpc request on grpc route (non-grpc content-type)", function()
        local body, headers = proxy_client_h2c({
          headers = {
            ["method"] = "POST",
            ["content-type"] = "application/json",
            [":authority"] = "grpc",
          }
        })
        assert.same("415", headers:get(":status"))
        assert.same('{"message":"Non-gRPC request matched gRPC route"}', body)
      end)

      it("non-grpc request on grpcs route (non-grpc content-type)", function()
        local body, headers = proxy_client_h2({
          headers = {
            ["method"] = "POST",
            ["content-type"] = "application/json",
            [":authority"] = "grpcs",
          }
        })
        assert.same("415", headers:get(":status"))
        assert.same('{"message":"Non-gRPC request matched gRPC route"}', body)
      end)

      it("grpc on grpcs route", function()
        local ok, resp = proxy_client_grpc({
          service = "hello.HelloService.SayHello",
          body = {
            greeting = "world!"
          },
          opts = {
            ["-authority"] = "grpcs",
          }
        })
        assert.falsy(ok)
        assert.matches("Code: Canceled", resp, nil, true)
        assert.matches("Message: gRPC request matched gRPCs route", resp, nil, true)
      end)
    end)
  end)
end

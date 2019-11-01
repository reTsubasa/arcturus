-- ngx_http_core_module Embedded Variables
-- http://nginx.org/en/docs/http/ngx_http_core_module.html#variables

local raw_header = ngx.req.raw_header

local function rewrite(ctx)
    ctx.req.remote_addr = ngx.var.remote_addr
    ctx.req.binary_remote_addr = ngx.var.binary_remote_addr
    ctx.req.content_length = ngx.var.content_length
    ctx.req.content_type = ngx.var.content_type
    ctx.req.http_user_agent = ngx.var.http_user_agent
    ctx.req.request_uri = ngx.unescape_uri(ngx.var.request_uri)
    ctx.req.request = ngx.var.request
    ctx.req.scheme = ngx.var.scheme
    ctx.req.server_port = ngx.var.server_port
    ctx.req.server_protocol = ngx.var.server_protocol
    ctx.req.host = ngx.var.host
    ctx.req.http_via = ngx.var.http_via
    ctx.req.request_body = ngx.var.request_body
    ctx.req.raw_xff = ngx.var.http_x_forwarded_for
    ctx.req.request_method = ngx.var.request_method
    ctx.req.hostname = ngx.var.hostname
    ctx.req.raw_header = raw_header()
    ctx.req.time = ngx.var.request_time
    ctx.req.pid = ngx.var.pid
    ctx.server_protocol = ngx.var.server_protocol
end

local fetch = {
    -- init_worker = init_worker,
    -- ssl_cert = ssl_cert,
    -- ssl_session_fetch = ssl_session_fetch,
    -- ssl_session_store = ssl_session_store,
    -- set = set,
    rewrite = rewrite
    -- access = access,
    -- content = content,
    -- balancer = balancer,
    -- header_filter = header_filter,
    -- body_filter = body_filter,
    -- log = log,
    -- timer = timer,
}

return function(ctx, phase)
    return fetch[phase](ctx)
end

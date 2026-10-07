import type { ProxyFault } from "./contracts";
import { PROVIDER_ID } from "./contracts";

export function jsonResponse(
  body: unknown,
  status: number,
  requestID: string,
  cacheStatus: string,
  extraHeaders: HeadersInit = {}
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "private, no-store",
      "content-security-policy": "default-src 'none'; frame-ancestors 'none'",
      "cross-origin-resource-policy": "same-origin",
      "permissions-policy": "camera=(), geolocation=(), microphone=()",
      "x-content-type-options": "nosniff",
      "referrer-policy": "no-referrer",
      "x-request-id": requestID,
      "x-trainy-cache": cacheStatus,
      ...extraHeaders
    }
  });
}

export function errorResponse(fault: ProxyFault, requestID: string, providerID: string = PROVIDER_ID): Response {
  const retry = fault.retryAfterSeconds;
  return jsonResponse({
    provider_id: providerID,
    status: fault.publicStatus,
    error: {
      code: fault.code,
      message: fault.publicMessage,
      ...(retry ? { retryAfterSeconds: retry } : {})
    },
    requestId: requestID
  }, fault.httpStatus, requestID, "none", {
    ...(retry ? { "retry-after": String(retry) } : {}),
    ...(fault.httpStatus === 405 ? { allow: "GET" } : {})
  });
}

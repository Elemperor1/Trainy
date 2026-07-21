import { handleRequest } from "./handler";

export { NSUpstreamQuota } from "./quota";

export default {
  fetch(request: Request, env: Env, context: ExecutionContext): Promise<Response> {
    return handleRequest(request, env, context);
  }
} satisfies ExportedHandler<Env>;

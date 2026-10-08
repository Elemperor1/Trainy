import { handleRequest } from "./handler";
import { runScheduledIngest } from "./japan/ingest";

export { NSUpstreamQuota } from "./quota";

export default {
  fetch(request: Request, env: Env, context: ExecutionContext): Promise<Response> {
    return handleRequest(request, env, context);
  },
  scheduled(_controller: ScheduledController, env: Env, context: ExecutionContext): void {
    context.waitUntil(runScheduledIngest(env));
  }
} satisfies ExportedHandler<Env>;

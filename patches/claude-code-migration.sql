CREATE TABLE IF NOT EXISTS "claude_code_bindings" (
	"worker_id" text PRIMARY KEY NOT NULL,
	"user_id" text NOT NULL,
	"workspace_id" text,
	"enabled" boolean DEFAULT false NOT NULL,
	"secret_hash" text NOT NULL,
	"auth_status" text DEFAULT 'unknown' NOT NULL,
	"capabilities" jsonb DEFAULT '{}'::jsonb NOT NULL,
	"last_seen_at" timestamp with time zone,
	"accessed_at" timestamp with time zone DEFAULT now() NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "claude_code_events" (
	"run_id" text NOT NULL,
	"sequence" integer NOT NULL,
	"payload" jsonb NOT NULL,
	"payload_hash" text NOT NULL,
	"projected" boolean DEFAULT false NOT NULL,
	"accessed_at" timestamp with time zone DEFAULT now() NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "claude_code_events_run_id_sequence_pk" PRIMARY KEY("run_id","sequence")
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "claude_code_runs" (
	"operation_id" text PRIMARY KEY NOT NULL,
	"user_id" text NOT NULL,
	"workspace_id" text,
	"topic_id" text NOT NULL,
	"thread_id" text,
	"worker_id" text NOT NULL,
	"request_id" text NOT NULL,
	"request_hash" text NOT NULL,
	"status" text DEFAULT 'queued' NOT NULL,
	"prepared_request" jsonb NOT NULL,
	"lease_token_hash" text,
	"lease_expires_at" timestamp with time zone,
	"heartbeat_at" timestamp with time zone,
	"queued_at" timestamp with time zone DEFAULT now() NOT NULL,
	"started_at" timestamp with time zone,
	"ended_at" timestamp with time zone,
	"error" text,
	"last_event_sequence" integer DEFAULT 0 NOT NULL,
	"projected_sequence" integer DEFAULT 0 NOT NULL,
	"accessed_at" timestamp with time zone DEFAULT now() NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "claude_code_tool_receipts" (
	"run_id" text NOT NULL,
	"tool_call_id" text NOT NULL,
	"name" text NOT NULL,
	"argument_hash" text NOT NULL,
	"status" text DEFAULT 'started' NOT NULL,
	"result" jsonb,
	"accessed_at" timestamp with time zone DEFAULT now() NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "claude_code_tool_receipts_run_id_tool_call_id_pk" PRIMARY KEY("run_id","tool_call_id")
);
--> statement-breakpoint
ALTER TABLE "claude_code_bindings" DROP CONSTRAINT IF EXISTS "claude_code_bindings_user_id_users_id_fk";
--> statement-breakpoint
ALTER TABLE "claude_code_bindings" ADD CONSTRAINT "claude_code_bindings_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "claude_code_bindings" DROP CONSTRAINT IF EXISTS "claude_code_bindings_workspace_id_workspaces_id_fk";
--> statement-breakpoint
ALTER TABLE "claude_code_bindings" ADD CONSTRAINT "claude_code_bindings_workspace_id_workspaces_id_fk" FOREIGN KEY ("workspace_id") REFERENCES "public"."workspaces"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "claude_code_events" DROP CONSTRAINT IF EXISTS "claude_code_events_run_id_claude_code_runs_operation_id_fk";
--> statement-breakpoint
ALTER TABLE "claude_code_events" ADD CONSTRAINT "claude_code_events_run_id_claude_code_runs_operation_id_fk" FOREIGN KEY ("run_id") REFERENCES "public"."claude_code_runs"("operation_id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "claude_code_runs" DROP CONSTRAINT IF EXISTS "claude_code_runs_operation_id_agent_operations_id_fk";
--> statement-breakpoint
ALTER TABLE "claude_code_runs" ADD CONSTRAINT "claude_code_runs_operation_id_agent_operations_id_fk" FOREIGN KEY ("operation_id") REFERENCES "public"."agent_operations"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "claude_code_runs" DROP CONSTRAINT IF EXISTS "claude_code_runs_user_id_users_id_fk";
--> statement-breakpoint
ALTER TABLE "claude_code_runs" ADD CONSTRAINT "claude_code_runs_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "claude_code_runs" DROP CONSTRAINT IF EXISTS "claude_code_runs_workspace_id_workspaces_id_fk";
--> statement-breakpoint
ALTER TABLE "claude_code_runs" ADD CONSTRAINT "claude_code_runs_workspace_id_workspaces_id_fk" FOREIGN KEY ("workspace_id") REFERENCES "public"."workspaces"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "claude_code_runs" DROP CONSTRAINT IF EXISTS "claude_code_runs_topic_id_topics_id_fk";
--> statement-breakpoint
ALTER TABLE "claude_code_runs" ADD CONSTRAINT "claude_code_runs_topic_id_topics_id_fk" FOREIGN KEY ("topic_id") REFERENCES "public"."topics"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "claude_code_runs" DROP CONSTRAINT IF EXISTS "claude_code_runs_thread_id_threads_id_fk";
--> statement-breakpoint
ALTER TABLE "claude_code_runs" ADD CONSTRAINT "claude_code_runs_thread_id_threads_id_fk" FOREIGN KEY ("thread_id") REFERENCES "public"."threads"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "claude_code_runs" DROP CONSTRAINT IF EXISTS "claude_code_runs_worker_id_claude_code_bindings_worker_id_fk";
--> statement-breakpoint
ALTER TABLE "claude_code_runs" ADD CONSTRAINT "claude_code_runs_worker_id_claude_code_bindings_worker_id_fk" FOREIGN KEY ("worker_id") REFERENCES "public"."claude_code_bindings"("worker_id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "claude_code_tool_receipts" DROP CONSTRAINT IF EXISTS "claude_code_tool_receipts_run_id_claude_code_runs_operation_id_fk";
--> statement-breakpoint
ALTER TABLE "claude_code_tool_receipts" ADD CONSTRAINT "claude_code_tool_receipts_run_id_claude_code_runs_operation_id_fk" FOREIGN KEY ("run_id") REFERENCES "public"."claude_code_runs"("operation_id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE UNIQUE INDEX IF NOT EXISTS "claude_code_bindings_owner_unique" ON "claude_code_bindings" USING btree ("user_id",coalesce("workspace_id", ''));--> statement-breakpoint
CREATE UNIQUE INDEX IF NOT EXISTS "claude_code_runs_request_unique" ON "claude_code_runs" USING btree ("user_id",coalesce("workspace_id", ''),"request_id");--> statement-breakpoint
CREATE UNIQUE INDEX IF NOT EXISTS "claude_code_runs_single_active" ON "claude_code_runs" USING btree ((1)) WHERE "claude_code_runs"."status" IN ('running', 'cancelling');--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "claude_code_runs_queue_idx" ON "claude_code_runs" USING btree ("status","queued_at");--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "claude_code_runs_owner_topic_idx" ON "claude_code_runs" USING btree ("user_id","topic_id");
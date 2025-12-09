/**
 * WorkerEntrypoint Shim for Melange Cloudflare Bindings
 *
 * This shim provides a bridge between OCaml/Melange functional handlers
 * and Cloudflare's WorkerEntrypoint class-based API.
 *
 * The WorkerEntrypoint class allows Workers to expose RPC methods and
 * handle multiple event types in a single class-based interface.
 */

import { WorkerEntrypoint } from 'cloudflare:workers';

/**
 * Creates a WorkerEntrypoint class that delegates to provided handlers.
 *
 * This function takes an object containing optional handler functions
 * and returns a WorkerEntrypoint subclass that delegates to those handlers.
 *
 * @param {Object} handlers - Handler functions from OCaml/Melange
 * @param {Function} [handlers.fetch] - HTTP request handler
 * @param {Function} [handlers.scheduled] - Cron trigger handler
 * @param {Function} [handlers.queue] - Queue message handler
 * @param {Function} [handlers.email] - Email message handler
 * @param {Function} [handlers.tail] - Tail event handler
 * @param {Function} [handlers.alarm] - Durable Object alarm handler
 * @returns {WorkerEntrypoint} A WorkerEntrypoint class instance
 */
export function makeWorkerEntrypoint(handlers) {
  return class extends WorkerEntrypoint {
    constructor(ctx, env) {
      super(ctx, env);
      this._handlers = handlers;
    }

    /**
     * Handle HTTP requests
     * @param {Request} request - The incoming HTTP request
     * @returns {Promise<Response>} A promise resolving to a Response
     */
    async fetch(request) {
      if (this._handlers.fetch) {
        // Call OCaml handler with (request, env, ctx)
        return await this._handlers.fetch(request, this.env, this.ctx);
      }
      // Fallback to parent implementation if no handler provided
      return await super.fetch(request);
    }

    /**
     * Handle scheduled events (cron triggers)
     * @param {ScheduledController} controller - The scheduled event controller
     * @returns {Promise<void>}
     */
    async scheduled(controller) {
      if (this._handlers.scheduled) {
        // Call OCaml handler with (event, env, ctx)
        return await this._handlers.scheduled(controller, this.env, this.ctx);
      }
    }

    /**
     * Handle queue messages
     * @param {MessageBatch} batch - The batch of queue messages
     * @returns {Promise<void>}
     */
    async queue(batch) {
      if (this._handlers.queue) {
        // Call OCaml handler with (batch, env, ctx)
        return await this._handlers.queue(batch, this.env, this.ctx);
      }
    }

    /**
     * Handle incoming emails
     * @param {ForwardableEmailMessage} message - The incoming email
     * @returns {Promise<void>}
     */
    async email(message) {
      if (this._handlers.email) {
        // Call OCaml handler with (message, env, ctx)
        return await this._handlers.email(message, this.env, this.ctx);
      }
    }

    /**
     * Handle tail events (execution logs from other Workers)
     * @param {TraceItem[]} events - Array of trace items
     * @returns {Promise<void>}
     */
    async tail(events) {
      if (this._handlers.tail) {
        // Call OCaml handler with (events, env, ctx)
        return await this._handlers.tail(events, this.env, this.ctx);
      }
    }

    /**
     * Handle Durable Object alarms
     * @returns {Promise<void>}
     */
    async alarm() {
      if (this._handlers.alarm) {
        // Alarm handler receives optional alarm info
        // For now, we don't pass alarm info - can be enhanced later
        return await this._handlers.alarm(undefined);
      }
    }
  };
}

--!strict
-- Tiny single-payload signal for client state change notifications. Owner: agent D.
export type Connection = { Disconnect: (self: Connection) -> () }

export type Signal<T> = {
	Connect: (self: Signal<T>, fn: (T) -> ()) -> Connection,
	Fire: (self: Signal<T>, value: T) -> (),
}

type SignalImpl<T> = Signal<T> & { _handlers: { [number]: (T) -> () }, _nextId: number }

local Signal = {}

function Signal.new<T>(): Signal<T>
	local self: SignalImpl<T> = {
		_handlers = {},
		_nextId = 0,
		Connect = function(this: Signal<T>, fn: (T) -> ()): Connection
			local impl = this :: SignalImpl<T>
			impl._nextId += 1
			local id = impl._nextId
			impl._handlers[id] = fn
			return {
				Disconnect = function()
					impl._handlers[id] = nil
				end,
			}
		end,
		Fire = function(this: Signal<T>, value: T)
			local impl = this :: SignalImpl<T>
			for _, fn in table.clone(impl._handlers) do
				task.spawn(fn, value)
			end
		end,
	} :: any
	return self
end

return Signal

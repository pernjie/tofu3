extends Node

# Game flow
signal turn_started(turn_number: int)
signal turn_ended(turn_number: int)
signal phase_changed(phase: String)

# Guest events
signal guest_spawned(guest)
signal guest_moved(guest, from_tile, to_tile)
signal guest_entered_stall(guest, stall)
signal guest_exited_stall(guest, stall)
signal guest_served(guest, stall)
signal guest_need_fulfilled(guest, need_type, amount, source)
signal guest_ascended(guest)
signal guest_descended(guest)
signal guest_banished(guest)
signal service_tick(guest, stall, turns_remaining)

# Beast events
signal beast_interacted(beast, guest)

# Midnight
signal midnight_reached

# Stall events
signal stall_placed(stall, tile)
signal stall_upgraded(stall, new_tier)
signal stall_restocked(stall)
signal stall_depleted(stall)

# Relic events
signal relic_placed(relic, tile)

# Card events
signal card_drawn(card)
signal card_played(card)

# Status events
signal status_applied(target, status)
signal status_removed(target, status)
signal status_stack_changed(status, old_stacks, new_stacks)

# Economy
signal tokens_changed(old_value: int, new_value: int)
signal reputation_changed(old_value: int, new_value: int)

# Level flow
signal level_started
signal level_won
signal level_lost
signal run_won
signal run_lost

# Debug
signal debug_show_guest(guest: GuestInstance)
signal debug_show_stall(stall: StallInstance)
signal debug_show_relic(relic: RelicInstance)

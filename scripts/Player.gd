extends Node

signal gold_changed(new_amount)
signal xp_changed(new_xp, required_xp)
signal level_changed(new_level)
signal health_changed(new_health)
signal not_enough_gold()

# Player economy
var gold: int = 0
var level: int = 1
var xp: int = 0

# Player health
var health: int = 100

# XP required per level
const BASE_XP_REQUIRED = 2
const XP_REQUIRED_INCREASE = 2

# Interest thresholds (0 gold = 0 interest, 10 gold = 1 interest, etc)
const INTEREST_THRESHOLD = 10
const MAX_INTEREST = 5

# Constants
const XP_PER_PURCHASE = 4
const BASE_XP_COST = 4
const REROLL_COST = 2
const STARTING_GOLD = 20

func _ready():
	# Initialize with starting gold
	set_gold(STARTING_GOLD)

# Set gold amount
func set_gold(amount: int):
	# Prevent gold from going below 0
	gold = max(amount, 0)
	emit_signal("gold_changed", gold)

# Add gold (can be negative to subtract)
func add_gold(amount: int):
	var new_amount = gold + amount
	
	# Check if we'll have enough gold for a negative transaction
	if amount < 0 and new_amount < 0:
		emit_signal("not_enough_gold")
		return false
	
	# Set the new gold amount (this will already prevent going below 0)
	set_gold(new_amount)
	return true

# Calculate XP needed for next level
func xp_required_for_level(target_level: int) -> int:
	return BASE_XP_REQUIRED + (target_level - 2) * XP_REQUIRED_INCREASE

# Get required XP for current level up
func get_required_xp() -> int:
	return xp_required_for_level(level + 1)

# Add XP to the player
func add_xp(amount: int):
	xp += amount
	
	# Check for level ups
	var required_xp = get_required_xp()
	while xp >= required_xp and level < 9:
		xp -= required_xp
		level_up()
		required_xp = get_required_xp()
	
	emit_signal("xp_changed", xp, get_required_xp())

# Purchase XP with gold
func buy_xp():
	if gold < BASE_XP_COST:
		emit_signal("not_enough_gold")
		return false
		
	if add_gold(-BASE_XP_COST):
		add_xp(XP_PER_PURCHASE)
		return true
	return false

# Level up the player
func level_up():
	level += 1
	emit_signal("level_changed", level)

# Pay for a shop reroll
func pay_reroll() -> bool:
	if gold < REROLL_COST:
		emit_signal("not_enough_gold")
		return false
		
	return add_gold(-REROLL_COST)

# Pay for a character
func pay_for_character(character: Character) -> bool:
	if gold < character.cost:
		emit_signal("not_enough_gold")
		return false
		
	return add_gold(-character.cost)

# Set player health
func set_health(new_health: int):
	health = new_health
	emit_signal("health_changed", health)

# Take damage
func take_damage(damage: int):
	set_health(health - damage)
	return health <= 0  # Return whether player is defeated

# Add interest based on current gold
func add_interest():
	var interest = min(gold / float(INTEREST_THRESHOLD), MAX_INTEREST)
	add_gold(interest)
	return interest

# Start a new round (add base gold, interest)
func start_round():
	# Add base gold for the round
	add_gold(5)
	
	# Add interest based on current gold
	var interest = add_interest()
	
	# Return info about gold gained
	return {
		"base_gold": 5,
		"interest": interest,
		"total": 5 + interest
	}

# Sell a character
func sell_character(character: Character):
	# Return gold based on unit cost
	add_gold(character.cost)

extends CityBotController
## Benchmark-only positioning; targeting, aiming, navigation and kit intents stay shared.
var hold_position: Vector3

func decide() -> void:
	super.decide()
	destination = hold_position

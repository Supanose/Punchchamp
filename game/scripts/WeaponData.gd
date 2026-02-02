class_name WeaponData
extends Resource

@export var weapon_name: String
@export var damage_mult: float
@export var speed_mult: float
@export var reach: float
@export var knockback_mult: float
@export var core_type: PartPickup.CoreType

func _init(name: String = "", dmg: float = 1.0, spd: float = 1.0, rch: float = 0.0, kb: float = 1.0, core: PartPickup.CoreType = PartPickup.CoreType.BLADE):
	weapon_name = name
	damage_mult = dmg
	speed_mult = spd
	reach = rch
	knockback_mult = kb
	core_type = core

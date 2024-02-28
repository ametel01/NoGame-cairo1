use nogame::compound::compound::{ICompoundDispatcher, ICompoundDispatcherTrait};
use nogame::defence::defence::{IDefenceDispatcher, IDefenceDispatcherTrait};
use nogame::dockyard::dockyard::{IDockyardDispatcher, IDockyardDispatcherTrait};
use nogame::fleet_movements::fleet_movements::{
    IFleetMovementsDispatcher, IFleetMovementsDispatcherTrait
};
use nogame::fleet_movements::library as fleet;
use nogame::libraries::types::{
    Fleet, Unit, TechLevels, PlanetPosition, ERC20s, Defences, ShipBuildType, DefenceBuildType,
    TechUpgradeType, CompoundUpgradeType, Names, MissionCategory
};
use nogame::planet::planet::{IPlanetDispatcher, IPlanetDispatcherTrait};
use nogame::storage::storage::{IStorageDispatcher, IStorageDispatcherTrait};
use nogame::tech::tech::{ITechDispatcher, ITechDispatcherTrait};

use snforge_std::{
    declare, ContractClassTrait, start_prank, start_warp, spy_events, SpyOn, EventSpy,
    EventAssertions, EventFetcher, event_name_hash, Event, CheatTarget
};
use starknet::info::{get_block_timestamp, get_contract_address};

use tests::utils::{
    ACCOUNT1, ACCOUNT2, set_up, init_game, YEAR, warp_multiple, Dispatchers, DAY, init_storage,
    prank_contracts,
};

#[test]
fn test_send_fleet_success() {
    let dsp: Dispatchers = set_up();
    init_game(dsp);

    prank_contracts(dsp, ACCOUNT1());
    dsp.planet.generate_planet();
    prank_contracts(dsp, ACCOUNT2());
    dsp.planet.generate_planet();
    init_storage(dsp, 2);
    prank_contracts(dsp, ACCOUNT1());
    init_storage(dsp, 1);

    dsp.dockyard.process_ship_build(ShipBuildType::Carrier(()), 1);
    dsp.dockyard.process_ship_build(ShipBuildType::Scraper(()), 1);
    dsp.dockyard.process_ship_build(ShipBuildType::Sparrow(()), 1);
    dsp.dockyard.process_ship_build(ShipBuildType::Frigate(()), 1);
    dsp.dockyard.process_ship_build(ShipBuildType::Armade(()), 1);

    let p2_position = dsp.storage.get_planet_position(2);

    let mut fleet: Fleet = Default::default();
    fleet.carrier = 1;
    fleet.scraper = 1;
    fleet.sparrow = 1;
    fleet.frigate = 1;
    fleet.armade = 1;

    assert(dsp.storage.get_ships_levels(1).carrier == 1, 'wrong ships before');
    assert(dsp.storage.get_ships_levels(1).scraper == 1, 'wrong ships before');
    assert(dsp.storage.get_ships_levels(1).sparrow == 1, 'wrong ships before');
    assert(dsp.storage.get_ships_levels(1).frigate == 1, 'wrong ships before');
    assert(dsp.storage.get_ships_levels(1).armade == 1, 'wrong ships before');

    let tritium_before = dsp.compound.get_spendable_resources(1).tritium;

    dsp.fleet.send_fleet(fleet, p2_position, MissionCategory::ATTACK, 100, 0);

    let tritium_after = dsp.compound.get_spendable_resources(1).tritium;

    assert(dsp.storage.get_ships_levels(2).carrier == 0, 'wrong ships after');
    assert(dsp.storage.get_ships_levels(2).scraper == 0, 'wrong ships after');
    assert(dsp.storage.get_ships_levels(2).sparrow == 0, 'wrong ships after');
    assert(dsp.storage.get_ships_levels(2).frigate == 0, 'wrong ships after');
    assert(dsp.storage.get_ships_levels(2).armade == 0, 'wrong ships after');
    let p1_position = dsp.storage.get_planet_position(1);
    let p2_position = dsp.storage.get_planet_position(2);

    let distance = fleet::get_distance(p1_position, p2_position);

    let fuel_consumption = fleet::get_fuel_consumption(fleet, distance);

    assert(tritium_after == tritium_before - fuel_consumption, 'wrong fuel consumption');

    let mission = dsp.storage.get_mission_details(1, 1);

    assert(mission.fleet.carrier == 1, 'wrong carrier');
    assert(mission.fleet.scraper == 1, 'wrong scraper');
    assert(mission.fleet.sparrow == 1, 'wrong sparrow');
    assert(mission.fleet.frigate == 1, 'wrong frigate');
    assert(mission.fleet.armade == 1, 'wrong armade');
}

#[test]
#[should_panic(expected: ('no planet at destination',))]
fn test_send_fleet_fails_no_planet_at_destination() {
    let dsp = set_up();
    init_game(dsp);

    prank_contracts(dsp, ACCOUNT1());
    dsp.planet.generate_planet();
    init_storage(dsp, 1);

    dsp.dockyard.process_ship_build(ShipBuildType::Carrier(()), 1);

    let p2_position = dsp.storage.get_planet_position(2);

    let mut fleet: Fleet = Default::default();
    fleet.carrier = 1;

    dsp.fleet.send_fleet(fleet, p2_position, MissionCategory::ATTACK, 100, 0);
}

#[test]
#[should_panic(expected: ('cannot attack own planet',))]
fn test_send_fleet_fails_origin_is_destination() {
    let dsp = set_up();
    init_game(dsp);

    prank_contracts(dsp, ACCOUNT1());
    dsp.planet.generate_planet();
    init_storage(dsp, 1);

    dsp.dockyard.process_ship_build(ShipBuildType::Carrier(()), 1);

    let p1_position = dsp.storage.get_planet_position(1);

    let mut fleet: Fleet = Default::default();
    fleet.carrier = 1;

    dsp.fleet.send_fleet(fleet, p1_position, MissionCategory::ATTACK, 100, 0);
}

#[test]
#[should_panic(expected: ('noob protection active',))]
fn test_send_fleet_fails_noob_protection() {
    let dsp = set_up();
    init_game(dsp);

    prank_contracts(dsp, ACCOUNT2());
    dsp.planet.generate_planet();
    prank_contracts(dsp, ACCOUNT1());
    dsp.planet.generate_planet();
    prank_contracts(dsp, ACCOUNT2());
    init_storage(dsp, 1);

    dsp.dockyard.process_ship_build(ShipBuildType::Carrier(()), 10);

    let p2_position = dsp.storage.get_planet_position(2);

    let mut fleet: Fleet = Default::default();
    fleet.carrier = 5;

    prank_contracts(dsp, ACCOUNT1());
    dsp.compound.process_upgrade(CompoundUpgradeType::SteelMine(()), 1);

    prank_contracts(dsp, ACCOUNT2());
    dsp.fleet.send_fleet(fleet, p2_position, MissionCategory::ATTACK, 100, 0);
}

#[test]
fn test_send_speed_modifier() {
    let dsp = set_up();
    init_game(dsp);

    prank_contracts(dsp, ACCOUNT2());
    dsp.planet.generate_planet();
    prank_contracts(dsp, ACCOUNT1());
    dsp.planet.generate_planet();
    init_storage(dsp, 1);
    prank_contracts(dsp, ACCOUNT2());
    init_storage(dsp, 2);

    dsp.dockyard.process_ship_build(ShipBuildType::Carrier(()), 10);

    let p2_position = dsp.storage.get_planet_position(2);

    let mut fleet: Fleet = Default::default();
    fleet.carrier = 5;

    prank_contracts(dsp, ACCOUNT1());
    dsp.compound.process_upgrade(CompoundUpgradeType::SteelMine(()), 1);

    prank_contracts(dsp, ACCOUNT2());
    dsp.fleet.send_fleet(fleet, p2_position, MissionCategory::ATTACK, 50, 0);
    let mission = dsp.storage.get_mission_details(1, 1);
    assert((mission.time_arrival - get_block_timestamp()) == 18125, 'wrong time arrival');
}

#[test]
#[should_panic(expected: ('max active missions',))]
fn test_send_fleet_fails_not_enough_fleet_slots() {
    let dsp = set_up();
    init_game(dsp);

    prank_contracts(dsp, ACCOUNT2());
    dsp.planet.generate_planet();
    prank_contracts(dsp, ACCOUNT1());
    dsp.planet.generate_planet();
    init_storage(dsp, 1);
    prank_contracts(dsp, ACCOUNT2());
    init_storage(dsp, 1);

    dsp.dockyard.process_ship_build(ShipBuildType::Carrier(()), 10);

    let p2_position = dsp.storage.get_planet_position(2);

    let mut fleet: Fleet = Default::default();
    fleet.carrier = 5;

    dsp.fleet.send_fleet(fleet, p2_position, MissionCategory::ATTACK, 100, 0);
    dsp.fleet.send_fleet(fleet, p2_position, MissionCategory::ATTACK, 100, 0);
}

#[test]
fn test_collect_debris_success() {
    let dsp = set_up();
    init_game(dsp);

    prank_contracts(dsp, ACCOUNT1());
    dsp.planet.generate_planet();
    prank_contracts(dsp, ACCOUNT2());
    dsp.planet.generate_planet();
    init_storage(dsp, 2);
    dsp.defence.process_defence_build(DefenceBuildType::Plasma(()), 1);
    prank_contracts(dsp, ACCOUNT1());
    init_storage(dsp, 1);
    dsp.tech.process_tech_upgrade(TechUpgradeType::Digital(()), 1);
    dsp.dockyard.process_ship_build(ShipBuildType::Carrier(()), 10);
    dsp.dockyard.process_ship_build(ShipBuildType::Scraper(()), 1);
    let p2_position = dsp.storage.get_planet_position(2);

    let mut fleet: Fleet = Default::default();
    fleet.carrier = 5;

    dsp.fleet.send_fleet(fleet, p2_position, MissionCategory::ATTACK, 100, 0);
    let mission = dsp.storage.get_mission_details(1, 1);
    start_warp(CheatTarget::All, mission.time_arrival + 1);
    dsp.fleet.attack_planet(1);

    let mut fleet: Fleet = Default::default();
    fleet.scraper = 1;
    let debris = dsp.storage.get_planet_debris_field(2);
    dsp.fleet.send_fleet(fleet, p2_position, MissionCategory::DEBRIS, 100, 0);
    let mission = dsp.storage.get_mission_details(1, 1);
    start_warp(CheatTarget::All, mission.time_arrival + 1);
    let resources_before = dsp.compound.get_spendable_resources(1);
    dsp.fleet.collect_debris(1);
    let scraper_back = dsp.storage.get_ships_levels(1).scraper;
    assert!(scraper_back == 1, "scraper back are {}, it should be 1", scraper_back);
    let resources_after = dsp.compound.get_spendable_resources(1);
    assert(resources_after.steel == resources_before.steel + debris.steel, 'wrong steel collected');
    assert(
        resources_after.quartz == resources_before.quartz + debris.quartz, 'wrong quartz collected'
    );
    let debris_after_collection = dsp.storage.get_planet_debris_field(2);
    assert(debris_after_collection.is_zero(), 'wrong debris after');
}

#[test]
fn test_collect_debris_own_planet() {
    let dsp = set_up();
    init_game(dsp);

    prank_contracts(dsp, ACCOUNT1());
    dsp.planet.generate_planet();
    prank_contracts(dsp, ACCOUNT2());
    dsp.planet.generate_planet();
    init_storage(dsp, 2);
    dsp.defence.process_defence_build(DefenceBuildType::Plasma(()), 1);
    dsp.dockyard.process_ship_build(ShipBuildType::Scraper(()), 1);
    dsp.tech.process_tech_upgrade(TechUpgradeType::Digital(()), 1);
    prank_contracts(dsp, ACCOUNT1());
    init_storage(dsp, 1);
    dsp.tech.process_tech_upgrade(TechUpgradeType::Digital(()), 1);
    dsp.dockyard.process_ship_build(ShipBuildType::Carrier(()), 1);
    let p2_position = dsp.storage.get_planet_position(2);

    let mut fleet: Fleet = Default::default();
    fleet.carrier = 1;

    dsp.fleet.send_fleet(fleet, p2_position, MissionCategory::ATTACK, 100, 0);
    let mission = dsp.storage.get_mission_details(1, 1);
    start_warp(CheatTarget::All, mission.time_arrival + 1);
    dsp.fleet.attack_planet(1);

    let mut fleet: Fleet = Default::default();
    fleet.scraper = 1;
    let debris = dsp.storage.get_planet_debris_field(2);
    prank_contracts(dsp, ACCOUNT2());
    dsp.fleet.send_fleet(fleet, p2_position, MissionCategory::DEBRIS, 100, 0);
    let mission = dsp.storage.get_mission_details(2, 1);
    start_warp(CheatTarget::All, mission.time_arrival + 1);
    let resources_before = dsp.compound.get_spendable_resources(2);
    dsp.fleet.collect_debris(1);
    assert(dsp.storage.get_ships_levels(2).scraper == 1, 'wrong scraper back');
    let resources_after = dsp.compound.get_spendable_resources(2);
    assert(resources_after.steel == resources_before.steel + debris.steel, 'wrong steel collected');
    assert(
        resources_after.quartz == resources_before.quartz + debris.quartz, 'wrong quartz collected'
    );
    let debris_after_collection = dsp.storage.get_planet_debris_field(2);
    assert(debris_after_collection.is_zero(), 'wrong debris after');
}

#[test]
fn test_collect_debris_fleet_decay() {
    let dsp = set_up();
    init_game(dsp);

    prank_contracts(dsp, ACCOUNT1());
    dsp.planet.generate_planet();
    prank_contracts(dsp, ACCOUNT2());
    dsp.planet.generate_planet();
    init_storage(dsp, 2);
    dsp.defence.process_defence_build(DefenceBuildType::Plasma(()), 1);
    prank_contracts(dsp, ACCOUNT1());
    init_storage(dsp, 1);
    dsp.tech.process_tech_upgrade(TechUpgradeType::Digital(()), 1);
    dsp.dockyard.process_ship_build(ShipBuildType::Carrier(()), 100);
    dsp.dockyard.process_ship_build(ShipBuildType::Scraper(()), 10);
    let p2_position = dsp.storage.get_planet_position(2);

    let mut fleet: Fleet = Default::default();
    fleet.carrier = 100;

    dsp.fleet.send_fleet(fleet, p2_position, MissionCategory::ATTACK, 100, 0);
    let mission = dsp.storage.get_mission_details(1, 1);
    start_warp(CheatTarget::All, mission.time_arrival + 1);
    dsp.fleet.attack_planet(1);

    let mut fleet: Fleet = Default::default();
    fleet.scraper = 10;
    let debris = dsp.storage.get_planet_debris_field(2);
    dsp.fleet.send_fleet(fleet, p2_position, MissionCategory::DEBRIS, 100, 0);
    let mission = dsp.storage.get_mission_details(1, 1);
    warp_multiple(dsp.planet.contract_address, get_contract_address(), mission.time_arrival + 9000);
    let resources_before = dsp.compound.get_spendable_resources(1);

    dsp.fleet.collect_debris(1);

    assert(dsp.storage.get_ships_levels(1).scraper == 5, 'wrong scraper back');

    let resources_after = dsp.compound.get_spendable_resources(1);
    assert(resources_after.steel == resources_before.steel + 50000, 'wrong steel collected');
    assert(resources_after.quartz == resources_before.quartz + 50000, 'wrong quartz collected');
    let debris_after_collection = dsp.storage.get_planet_debris_field(2);
    assert(debris_after_collection.steel == debris.steel - 50000, 'wrong steel after');
    assert(debris_after_collection.quartz == debris.quartz - 50000, 'wrong quartz after');
}

#[test]
#[should_panic(expected: ('empty debris fiels',))]
fn test_send_fleet_debris_fails_empty_debris_field() {
    let dsp = set_up();
    init_game(dsp);

    prank_contracts(dsp, ACCOUNT1());
    dsp.planet.generate_planet();
    prank_contracts(dsp, ACCOUNT2());
    dsp.planet.generate_planet();
    init_storage(dsp, 2);
    prank_contracts(dsp, ACCOUNT1());
    init_storage(dsp, 1);
    dsp.tech.process_tech_upgrade(TechUpgradeType::Digital(()), 1);
    dsp.dockyard.process_ship_build(ShipBuildType::Carrier(()), 10);
    dsp.dockyard.process_ship_build(ShipBuildType::Scraper(()), 1);
    let p2_position = dsp.storage.get_planet_position(2);

    let mut fleet: Fleet = Default::default();
    fleet.scraper = 1;

    dsp.fleet.send_fleet(fleet, p2_position, MissionCategory::DEBRIS, 100, 0);
    let mission = dsp.storage.get_mission_details(1, 1);
    start_warp(CheatTarget::All, mission.time_arrival + 1);
    dsp.fleet.collect_debris(2);
}

#[test]
#[should_panic(expected: ('no scrapers for collection',))]
fn test_send_fleet_debris_fails_no_scrapers() {
    let dsp = set_up();
    init_game(dsp);

    prank_contracts(dsp, ACCOUNT1());
    dsp.planet.generate_planet();
    prank_contracts(dsp, ACCOUNT2());
    dsp.planet.generate_planet();
    init_storage(dsp, 2);
    dsp.defence.process_defence_build(DefenceBuildType::Plasma(()), 1);
    prank_contracts(dsp, ACCOUNT1());
    init_storage(dsp, 1);
    dsp.tech.process_tech_upgrade(TechUpgradeType::Digital(()), 1);
    dsp.dockyard.process_ship_build(ShipBuildType::Carrier(()), 2);
    let p1_position = dsp.storage.get_planet_position(2);

    let mut fleet: Fleet = Default::default();
    fleet.carrier = 1;

    dsp.fleet.send_fleet(fleet, p1_position, MissionCategory::ATTACK, 100, 0);
    let mission = dsp.storage.get_mission_details(1, 1);
    start_warp(CheatTarget::All, mission.time_arrival + 1);
    dsp.fleet.attack_planet(1);

    dsp.fleet.send_fleet(fleet, p1_position, MissionCategory::DEBRIS, 100, 0);
}

#[test]
fn test_attack_planet() {
    let dsp = set_up();
    init_game(dsp);

    prank_contracts(dsp, ACCOUNT1());
    dsp.planet.generate_planet();
    prank_contracts(dsp, ACCOUNT2());
    dsp.planet.generate_planet();
    init_storage(dsp, 2);
    dsp.defence.process_defence_build(DefenceBuildType::Celestia(()), 100);
    prank_contracts(dsp, ACCOUNT1());
    init_storage(dsp, 1);
    dsp.dockyard.process_ship_build(ShipBuildType::Armade(()), 10);

    let p2_position = dsp.storage.get_planet_position(2);
    let mut fleet_a: Fleet = Default::default();
    fleet_a.armade = 10;
    dsp.fleet.send_fleet(fleet_a, p2_position, MissionCategory::ATTACK, 100, 0);
    let mission = dsp.storage.get_mission_details(1, 1);
    start_warp(CheatTarget::All, mission.time_arrival + 1);

    dsp.fleet.attack_planet(1);
}

#[test]
fn test_attack_planet_fleet_decay() {
    let dsp = set_up();
    init_game(dsp);

    prank_contracts(dsp, ACCOUNT1());
    dsp.planet.generate_planet();
    prank_contracts(dsp, ACCOUNT2());
    dsp.planet.generate_planet();
    init_storage(dsp, 2);
    prank_contracts(dsp, ACCOUNT1());
    init_storage(dsp, 1);
    dsp.dockyard.process_ship_build(ShipBuildType::Carrier(()), 10);

    let p2_position = dsp.storage.get_planet_position(2);
    let mut fleet_a: Fleet = Default::default();
    fleet_a.carrier = 10;
    dsp.fleet.send_fleet(fleet_a, p2_position, MissionCategory::ATTACK, 100, 0);
    let mission = dsp.storage.get_mission_details(1, 1);

    // warping 2100 seconds over an hour to create fleet decay
    warp_multiple(dsp.planet.contract_address, get_contract_address(), mission.time_arrival + 9000);

    let points_before = dsp.storage.get_planet_points(1);

    let before = dsp.storage.get_ships_levels(1);
    assert(before.carrier == 0, 'wrong #1');

    dsp.fleet.attack_planet(1);

    let after = dsp.storage.get_ships_levels(1);
    assert(after.carrier == 5, 'wrong #2');

    let points_after = dsp.storage.get_planet_points(1);
    assert(points_before - points_after == 20, 'wrong #3');
}

#[test]
#[should_panic(expected: ('the mission is empty',))]
fn test_attack_planet_fails_empty_mission() {
    let dsp = set_up();
    init_game(dsp);

    prank_contracts(dsp, ACCOUNT1());
    dsp.planet.generate_planet();
    prank_contracts(dsp, ACCOUNT2());
    dsp.planet.generate_planet();
    init_storage(dsp, 2);
    prank_contracts(dsp, ACCOUNT1());
    init_storage(dsp, 1);
    dsp.dockyard.process_ship_build(ShipBuildType::Sparrow(()), 1);

    let p2_position = dsp.storage.get_planet_position(2);
    let mut fleet_a: Fleet = Default::default();
    fleet_a.sparrow = 1;

    dsp.fleet.send_fleet(fleet_a, p2_position, MissionCategory::ATTACK, 100, 0);
    let mission = dsp.storage.get_mission_details(1, 1);

    start_warp(CheatTarget::All, mission.time_arrival + 1);
    dsp.fleet.attack_planet(2)
}

#[test]
#[should_panic(expected: ('destination not reached yet',))]
fn test_attack_planet_fails_destination_not_reached() {
    let dsp = set_up();
    init_game(dsp);

    prank_contracts(dsp, ACCOUNT1());
    dsp.planet.generate_planet();
    prank_contracts(dsp, ACCOUNT2());
    dsp.planet.generate_planet();
    init_storage(dsp, 2);
    prank_contracts(dsp, ACCOUNT1());
    init_storage(dsp, 1);
    dsp.dockyard.process_ship_build(ShipBuildType::Sparrow(()), 1);
    let mut fleet_a: Fleet = Default::default();
    fleet_a.sparrow = 1;

    let p2_position = dsp.storage.get_planet_position(2);
    dsp.fleet.send_fleet(fleet_a, p2_position, MissionCategory::ATTACK, 100, 0);

    dsp.fleet.attack_planet(1)
}

#[test]
fn test_attack_planet_loot_amount() {
    let dsp = set_up();
    init_game(dsp);

    prank_contracts(dsp, ACCOUNT1());
    dsp.planet.generate_planet();
    prank_contracts(dsp, ACCOUNT2());
    dsp.planet.generate_planet();
    init_storage(dsp, 2);
    prank_contracts(dsp, ACCOUNT1());
    init_storage(dsp, 1);

    prank_contracts(dsp, ACCOUNT2());
    prank_contracts(dsp, ACCOUNT1());
    dsp.dockyard.process_ship_build(ShipBuildType::Carrier(()), 5);
    let mut fleet_a: Fleet = Default::default();
    fleet_a.carrier = 1;

    let p2_position = dsp.storage.get_planet_position(2);
    dsp.fleet.send_fleet(fleet_a, p2_position, MissionCategory::ATTACK, 100, 0);

    let attacker_spendable_before = dsp.compound.get_spendable_resources(1);

    let mission = dsp.storage.get_mission_details(1, 1);
    start_warp(CheatTarget::All, mission.time_arrival + 1);
    dsp.fleet.attack_planet(1);

    let attacker_spendable_after = dsp.compound.get_spendable_resources(1);
    let mut expected: ERC20s = Default::default();

    expected.steel = 3333;
    expected.quartz = 3333;
    expected.tritium = 3333;

    assert(
        (attacker_spendable_after - attacker_spendable_before) == expected, 'wrong attacker loot'
    );
}

#[test]
fn test_recall_fleet() {
    let dsp = set_up();
    init_game(dsp);

    prank_contracts(dsp, ACCOUNT1());
    dsp.planet.generate_planet();
    prank_contracts(dsp, ACCOUNT2());
    dsp.planet.generate_planet();
    init_storage(dsp, 2);
    prank_contracts(dsp, ACCOUNT1());
    init_storage(dsp, 1);
    dsp.dockyard.process_ship_build(ShipBuildType::Sparrow(()), 1);
    let fleet_before = dsp.storage.get_ships_levels(1);
    let mut fleet_a: Fleet = Default::default();
    fleet_a.sparrow = 1;

    let p2_position = dsp.storage.get_planet_position(2);
    dsp.fleet.send_fleet(fleet_a, p2_position, MissionCategory::ATTACK, 100, 0);
    warp_multiple(dsp.planet.contract_address, get_contract_address(), get_block_timestamp() + 60);
    dsp.fleet.recall_fleet(1);
    let fleet_after = dsp.storage.get_ships_levels(1);
    assert(fleet_after == fleet_before, 'wrong fleet after');
    let mission_after = dsp.storage.get_mission_details(1, 1);
    assert(mission_after == Zeroable::zero(), 'wrong mission after');
    assert(dsp.storage.get_active_missions(1).len() == 0, 'wrong active missions');
}

#[test]
#[should_panic(expected: ('no fleet to recall',))]
fn test_recall_fleet_fails_no_fleet_to_recall() {
    let dsp = set_up();
    init_game(dsp);

    prank_contracts(dsp, ACCOUNT1());
    dsp.planet.generate_planet();
    prank_contracts(dsp, ACCOUNT2());
    dsp.planet.generate_planet();
    init_storage(dsp, 2);
    prank_contracts(dsp, ACCOUNT1());
    init_storage(dsp, 1);
    dsp.dockyard.process_ship_build(ShipBuildType::Sparrow(()), 1);
    let mut fleet_a: Fleet = Default::default();
    fleet_a.sparrow = 1;

    let p2_position = dsp.storage.get_planet_position(2);
    dsp.fleet.send_fleet(fleet_a, p2_position, MissionCategory::ATTACK, 100, 0);
    warp_multiple(dsp.planet.contract_address, get_contract_address(), get_block_timestamp() + 60);
    dsp.fleet.recall_fleet(2);
}


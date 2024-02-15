use tests::utils::{
    ACCOUNT1, ACCOUNT2, set_up, init_game, YEAR, warp_multiple, Dispatchers, E18, init_storage
};
use nogame::game::interface::{INoGameDispatcher, INoGameDispatcherTrait};
use nogame::libraries::types::{
    ColonyUpgradeType, ColonyBuildType, BuildType, UpgradeType, Fleet, DefencesLevels,
    CompoundsLevels, DAY, PlanetPosition, ShipsLevels, ERC20s, Debris, MissionCategory
};
use snforge_std::{start_prank, CheatTarget, start_warp};

#[test]
fn test_generate_colony() {
    let dsp: Dispatchers = set_up();
    init_game(dsp);

    start_prank(CheatTarget::One(dsp.game.contract_address), ACCOUNT1());
    dsp.game.generate_planet();
    init_storage(dsp, 1);
    dsp.game.generate_colony();
    dsp.game.generate_colony();
    dsp.game.generate_colony();
    let colonies = dsp.game.get_planet_colonies(1);

    let position_a = PlanetPosition { system: 188, orbit: 10 };
    let position_b = PlanetPosition { system: 182, orbit: 2 };
    let position_c = PlanetPosition { system: 69, orbit: 8 };

    let (id, position) = *colonies.at(0);
    assert(id == 1 && position.system == 188 && position.orbit == 10, 'wrong assert 1');
    let (id, position) = *colonies.at(1);
    assert(id == 2 && position.system == 182 && position.orbit == 2, 'wrong assert 2');
    let (id, position) = *colonies.at(2);
    assert(id == 3 && position.system == 69 && position.orbit == 8, 'wrong assert 3');
// assert(dsp.game.get_position_slot_occupant(position_a) == 1001, 'wrong assert 4');
// assert(dsp.game.get_position_slot_occupant(position_b) == 1002, 'wrong assert 5');
// assert(dsp.game.get_position_slot_occupant(position_c) == 1003, 'wrong assert 6');
}

#[test]
fn test_collect_resources_all_planets() {
    let dsp: Dispatchers = set_up();
    init_game(dsp);

    start_prank(CheatTarget::One(dsp.game.contract_address), ACCOUNT1());
    dsp.game.generate_planet();
    init_storage(dsp, 1);

    dsp.game.generate_colony();
    dsp.game.generate_colony();
    dsp.game.generate_colony();

    start_warp(CheatTarget::One(dsp.game.contract_address), starknet::get_block_timestamp() + YEAR);
    let planet_collectible = dsp.game.get_collectible_resources(1);
    let colony1_collectible = dsp.game.get_colony_collectible_resources(1, 1);
    let colony2_collectible = dsp.game.get_colony_collectible_resources(1, 2);
    let colony3_collectible = dsp.game.get_colony_collectible_resources(1, 3);
    let planet_spendable = dsp.game.get_spendable_resources(1);
    dsp.game.collect_resources();
    let planet_spendable_after = dsp.game.get_spendable_resources(1);
    assert(
        planet_spendable_after == planet_spendable
            + planet_collectible
            + colony1_collectible
            + colony2_collectible
            + colony3_collectible,
        'wrong planet spendable'
    );
}

#[test]
fn test_send_fleet_to_colony() {
    let dsp: Dispatchers = set_up();
    init_game(dsp);

    start_prank(CheatTarget::One(dsp.game.contract_address), ACCOUNT1());
    dsp.game.generate_planet();
    init_storage(dsp, 1);

    dsp.game.generate_colony();
    dsp.game.process_ship_build(BuildType::Carrier(()), 1);

    let mut fleet: Fleet = Default::default();
    fleet.carrier = 1;

    let mut p2_position: PlanetPosition = Default::default();
    p2_position.system = 188;
    p2_position.orbit = 10;
    dsp.game.send_fleet(fleet, p2_position, MissionCategory::TRANSPORT, 100, 0);
    let missions = dsp.game.get_active_missions(1);
    let mission = *missions.at(0);
    assert(mission.destination == 1001, 'wrong hostile mission');
    assert(mission.category == MissionCategory::TRANSPORT, 'wrong hostile mission');
    start_warp(CheatTarget::One(dsp.game.contract_address), mission.time_arrival + 1);
    dsp.game.dock_fleet(1);
    assert(dsp.game.get_colony_ships_levels(1, 1).carrier == 1, 'wrong colony ships levels');
}

#[test]
fn test_send_fleet_from_colony() {
    let dsp: Dispatchers = set_up();
    init_game(dsp);

    start_prank(CheatTarget::One(dsp.game.contract_address), ACCOUNT1());
    dsp.game.generate_planet();
    init_storage(dsp, 1);
    dsp.game.generate_colony();

    dsp.game.process_colony_compound_upgrade(1, ColonyUpgradeType::Dockyard, 2);
    dsp.game.process_colony_unit_build(1, ColonyBuildType::Carrier, 1);

    let mut fleet: Fleet = Default::default();
    fleet.carrier = 1;

    let mut p2_position: PlanetPosition = dsp.game.get_planet_position(1);
    dsp.game.send_fleet(fleet, p2_position, MissionCategory::TRANSPORT, 100, 1);
    let missions = dsp.game.get_active_missions(1);
    let mission = *missions.at(0);
    assert(mission.destination == 1, 'wrong mission destination');
    assert(mission.category == MissionCategory::TRANSPORT, 'wrong mission category');
    start_warp(CheatTarget::One(dsp.game.contract_address), mission.time_arrival + 1);
    dsp.game.dock_fleet(1);
    assert(dsp.game.get_ships_levels(1).carrier == 1, 'wrong ships levels');
    assert(dsp.game.get_colony_ships_levels(1, 1).carrier == 0, 'wrong colony ships levels');
}

#[test]
fn test_attack_from_colony() {
    let dsp: Dispatchers = set_up();
    init_game(dsp);

    start_prank(CheatTarget::One(dsp.game.contract_address), ACCOUNT1());
    dsp.game.generate_planet();
    init_storage(dsp, 1);

    start_prank(CheatTarget::One(dsp.game.contract_address), ACCOUNT2());
    dsp.game.generate_planet();
    init_storage(dsp, 2);

    let mut fleet: Fleet = Default::default();
    fleet.carrier = 1;

    let p2_position = dsp.game.get_planet_position(2);

    start_prank(CheatTarget::One(dsp.game.contract_address), ACCOUNT1());
    dsp.game.generate_colony();
    dsp.game.process_colony_compound_upgrade(1, ColonyUpgradeType::Dockyard, 2);
    dsp.game.process_colony_unit_build(1, ColonyBuildType::Carrier, 1);

    dsp.game.send_fleet(fleet, p2_position, MissionCategory::ATTACK, 100, 1);
    let missions = dsp.game.get_active_missions(1);
    let mission = *missions.at(0);
    assert(mission.destination == 2, 'wrong mission destination');
    assert(mission.category == MissionCategory::ATTACK, 'wrong mission category');
    start_warp(CheatTarget::One(dsp.game.contract_address), mission.time_arrival + 1);
    dsp.game.attack_planet(1);
}

#[test]
fn test_process_colony_compound_upgrade() {
    let dsp: Dispatchers = set_up();
    init_game(dsp);

    start_prank(CheatTarget::One(dsp.game.contract_address), ACCOUNT1());
    dsp.game.generate_planet();
    init_storage(dsp, 1);

    let mut expected_compounds: CompoundsLevels = Default::default();
    expected_compounds.steel = 1;
    expected_compounds.quartz = 2;
    expected_compounds.tritium = 3;
    expected_compounds.energy = 4;
    expected_compounds.dockyard = 1;

    dsp.game.generate_colony();
    dsp.game.process_colony_compound_upgrade(1, ColonyUpgradeType::SteelMine, 1);
    dsp.game.process_colony_compound_upgrade(1, ColonyUpgradeType::QuartzMine, 2);
    dsp.game.process_colony_compound_upgrade(1, ColonyUpgradeType::TritiumMine, 3);
    dsp.game.process_colony_compound_upgrade(1, ColonyUpgradeType::EnergyPlant, 4);
    dsp.game.process_colony_compound_upgrade(1, ColonyUpgradeType::Dockyard, 1);
    let colony1_compounds = dsp.game.get_colony_compounds(1, 1);
    assert(colony1_compounds == expected_compounds, 'wrong c1 compounds');

    dsp.game.generate_colony();
    dsp.game.process_colony_compound_upgrade(2, ColonyUpgradeType::SteelMine, 1);
    dsp.game.process_colony_compound_upgrade(2, ColonyUpgradeType::QuartzMine, 2);
    dsp.game.process_colony_compound_upgrade(2, ColonyUpgradeType::TritiumMine, 3);
    dsp.game.process_colony_compound_upgrade(2, ColonyUpgradeType::EnergyPlant, 4);
    dsp.game.process_colony_compound_upgrade(2, ColonyUpgradeType::Dockyard, 1);
    let colony2_compounds = dsp.game.get_colony_compounds(1, 2);
    assert(colony2_compounds == expected_compounds, 'wrong c2 compounds');
}

#[test]
fn process_colony_unit_build_defences_test() {
    let dsp: Dispatchers = set_up();
    init_game(dsp);

    start_prank(CheatTarget::One(dsp.game.contract_address), ACCOUNT1());
    dsp.game.generate_planet();
    init_storage(dsp, 1);

    let mut expected: DefencesLevels = Default::default();
    expected.blaster = 1;
    expected.beam = 1;
    expected.astral = 1;
    expected.plasma = 1;
    expected.celestia = 1;

    dsp.game.generate_colony();
    dsp.game.process_colony_compound_upgrade(1, ColonyUpgradeType::Dockyard, 8);
    dsp.game.process_colony_unit_build(1, ColonyBuildType::Blaster, 1);
    dsp.game.process_colony_unit_build(1, ColonyBuildType::Beam, 1);
    dsp.game.process_colony_unit_build(1, ColonyBuildType::Astral, 1);
    dsp.game.process_colony_unit_build(1, ColonyBuildType::Plasma, 1);
    dsp.game.process_colony_unit_build(1, ColonyBuildType::Celestia, 1);
    let actual = dsp.game.get_colony_defences_levels(1, 1);
    assert(actual == expected, 'wrong c1 defences');
}

#[test]
fn process_colony_unit_build_fleet_test() {
    let dsp: Dispatchers = set_up();
    init_game(dsp);

    start_prank(CheatTarget::One(dsp.game.contract_address), ACCOUNT1());
    dsp.game.generate_planet();
    init_storage(dsp, 1);

    let mut expected: Fleet = Default::default();
    expected.carrier = 1;
    expected.scraper = 1;
    expected.sparrow = 1;
    expected.frigate = 1;
    expected.armade = 1;

    dsp.game.generate_colony();
    dsp.game.process_colony_compound_upgrade(1, ColonyUpgradeType::Dockyard, 8);
    dsp.game.process_colony_unit_build(1, ColonyBuildType::Carrier, 1);
    dsp.game.process_colony_unit_build(1, ColonyBuildType::Scraper, 1);
    dsp.game.process_colony_unit_build(1, ColonyBuildType::Sparrow, 1);
    dsp.game.process_colony_unit_build(1, ColonyBuildType::Frigate, 1);
    dsp.game.process_colony_unit_build(1, ColonyBuildType::Armade, 1);
    let actual = dsp.game.get_colony_ships_levels(1, 1);
    assert(actual == expected, 'wrong c1 ships');
}

#[test]
fn test_collect_colony_resources() {
    let dsp: Dispatchers = set_up();
    init_game(dsp);

    start_prank(CheatTarget::One(dsp.game.contract_address), ACCOUNT1());
    dsp.game.generate_planet();
    init_storage(dsp, 1);

    dsp.game.generate_colony();
    dsp.game.process_colony_compound_upgrade(1, ColonyUpgradeType::SteelMine, 1);
    dsp.game.process_colony_compound_upgrade(1, ColonyUpgradeType::QuartzMine, 2);
    dsp.game.process_colony_compound_upgrade(1, ColonyUpgradeType::TritiumMine, 3);
    dsp.game.process_colony_compound_upgrade(1, ColonyUpgradeType::EnergyPlant, 4);

    let planet_spendable_resources = dsp.game.get_spendable_resources(1);
    start_warp(CheatTarget::One(dsp.game.contract_address), starknet::get_block_timestamp() + DAY);
    let colony_collectible = dsp.game.get_colony_collectible_resources(1, 1);

    dsp.game.collect_colony_resources(1);
    let planet_spendable_resources_after = dsp.game.get_spendable_resources(1);
    let colony_collectible_after = dsp.game.get_colony_collectible_resources(1, 1);

    assert(
        planet_spendable_resources_after == planet_spendable_resources + colony_collectible,
        'wrong planet spendable'
    );
    assert(colony_collectible_after == Default::default(), 'wrong colony collectible');
}

#[test]
fn test_attack_colony() {
    let dsp = set_up();
    init_game(dsp);

    start_prank(CheatTarget::One(dsp.game.contract_address), ACCOUNT1());
    dsp.game.generate_planet();
    start_prank(CheatTarget::One(dsp.game.contract_address), ACCOUNT2());
    dsp.game.generate_planet();
    init_storage(dsp, 2);

    start_prank(CheatTarget::One(dsp.game.contract_address), ACCOUNT1());
    init_storage(dsp, 1);
    dsp.game.process_ship_build(BuildType::Carrier(()), 10);
    start_prank(CheatTarget::One(dsp.game.contract_address), ACCOUNT2());

    dsp.game.generate_colony();
    dsp.game.process_colony_compound_upgrade(1, ColonyUpgradeType::EnergyPlant, 4);
    dsp.game.process_colony_compound_upgrade(1, ColonyUpgradeType::SteelMine, 1);
    dsp.game.process_colony_compound_upgrade(1, ColonyUpgradeType::QuartzMine, 2);
    dsp.game.process_colony_compound_upgrade(1, ColonyUpgradeType::TritiumMine, 1);
    dsp.game.process_colony_compound_upgrade(1, ColonyUpgradeType::Dockyard, 1);
    dsp.game.process_colony_unit_build(1, ColonyBuildType::Blaster, 1);

    let colony_position = dsp.game.get_planet_position(2001);
    let mut fleet_a: Fleet = Default::default();
    fleet_a.carrier = 10;
    start_prank(CheatTarget::One(dsp.game.contract_address), ACCOUNT1());
    warp_multiple(
        dsp.game.contract_address,
        starknet::get_contract_address(),
        starknet::get_block_timestamp() + DAY * 7
    );
    dsp.game.send_fleet(fleet_a, colony_position, MissionCategory::ATTACK, 100, 0);
    let mission = dsp.game.get_mission_details(1, 1);
    warp_multiple(
        dsp.game.contract_address, starknet::get_contract_address(), mission.time_arrival + 1
    );
    let colony_resources = dsp.game.get_colony_collectible_resources(2, 1);
    let attacker_resources = dsp.game.get_spendable_resources(1);
    dsp.game.attack_planet(1);
    let attacker_resources_after = dsp.game.get_spendable_resources(1);
    let colony_resources_after = dsp.game.get_colony_collectible_resources(2, 1);

    let mut expected_attacker_resources: ERC20s = Default::default();
    expected_attacker_resources.steel = 5657;
    expected_attacker_resources.quartz = 8228;
    expected_attacker_resources.tritium = 2399;

    let mut expected_debris: Debris = Default::default();
    expected_debris.steel = 666;
    expected_debris.quartz = 666;

    assert(
        (attacker_resources_after - attacker_resources) == expected_attacker_resources,
        'wrong attacker resources'
    );
    assert(dsp.game.get_debris_field(2001) == expected_debris, 'wrong debris');
}

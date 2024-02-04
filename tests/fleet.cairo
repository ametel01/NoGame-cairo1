use starknet::info::get_block_timestamp;

use snforge_std::{declare, ContractClassTrait, PrintTrait, start_prank, start_warp};

use nogame::game::interface::{INoGameDispatcher, INoGameDispatcherTrait};
use nogame::libraries::types::{
    Fleet, Unit, TechLevels, PlanetPosition, ERC20s, DefencesLevels, Debris
};
use nogame::libraries::fleet;

use tests::utils::{ACCOUNT1, ACCOUNT2, set_up, init_game, YEAR, warp_multiple};

#[test]
fn test_war_basic() {
    let mut attackers: Fleet = Default::default();
    attackers.sparrow = 4;
    attackers.scraper = 15;
    attackers.carrier = 35;
    attackers.frigate = 10;
    attackers.armade = 10;
    let mut techs: TechLevels = Default::default();
    // techs.armour = 3;
    // techs.weapons = 3;
    let mut defenders: Fleet = Default::default();
    // defenders.sparrow = 100;
    // defenders.carrier = 0;
    // defenders.frigate = 4;
    let mut defences: DefencesLevels = Default::default();
    // defences.blaster = 20;
    // defences.beam = 1;
    // defences.astral = 10;    
    let (res1, res2, def) = fleet::war(attackers, techs, defenders, defences, Default::default());
}

#[test]
fn test_war_sparrow_vs_carrier() {
    let mut attackers: Fleet = Default::default();
    attackers.sparrow = 1;
    let mut defenders: Fleet = Default::default();
    defenders.carrier = 5;
    let mut defences: DefencesLevels = Default::default();
    let (res1, res2, def) = fleet::war(
        attackers, Default::default(), defenders, defences, Default::default()
    );
}

#[test]
fn test_war_frigate_vs_carrier() {
    let mut attackers: Fleet = Default::default();
    attackers.frigate = 1;
    let mut defenders: Fleet = Default::default();
    defenders.carrier = 45;
    let mut defences: DefencesLevels = Default::default();
    let (res1, res2, def) = fleet::war(
        attackers, Default::default(), defenders, defences, Default::default()
    );
}

#[test]
fn test_war_armade_vs_carrier() {
    let mut attackers: Fleet = Default::default();
    attackers.armade = 1;
    let mut defenders: Fleet = Default::default();
    defenders.carrier = 152;
    let mut defences: DefencesLevels = Default::default();
    let (res1, res2, def) = fleet::war(
        attackers, Default::default(), defenders, defences, Default::default()
    );
}

#[test]
fn test_war_armade_vs_sparrow() {
    let mut attackers: Fleet = Default::default();
    attackers.armade = 1;
    let mut defenders: Fleet = Default::default();
    defenders.sparrow = 30;
    let mut defences: DefencesLevels = Default::default();
    let (res1, res2, def) = fleet::war(
        attackers, Default::default(), defenders, defences, Default::default()
    );
}

#[test]
fn test_war_sparrow_vs_blaster() {
    let mut attackers: Fleet = Default::default();
    attackers.sparrow = 1;
    let mut defenders: Fleet = Default::default();
    let mut defences: DefencesLevels = Default::default();
    defences.blaster = 2;
    let (res1, res2, def) = fleet::war(
        attackers, Default::default(), defenders, defences, Default::default()
    );
}

#[test]
fn test_war_sparrow_vs_beam() {
    let mut attackers: Fleet = Default::default();
    attackers.sparrow = 3;
    let mut defenders: Fleet = Default::default();
    let mut defences: DefencesLevels = Default::default();
    defences.beam = 1;
    let (res1, res2, def) = fleet::war(
        attackers, Default::default(), defenders, defences, Default::default()
    );
}

#[test]
fn test_war_sparrow_vs_astral() {
    let mut attackers: Fleet = Default::default();
    attackers.sparrow = 20;
    let mut defenders: Fleet = Default::default();
    let mut defences: DefencesLevels = Default::default();
    defences.astral = 1;
    let (res1, res2, def) = fleet::war(
        attackers, Default::default(), defenders, defences, Default::default()
    );
}

#[test]
fn test_war_sparrow_vs_plasma() {
    let mut attackers: Fleet = Default::default();
    attackers.sparrow = 100;
    let mut defenders: Fleet = Default::default();
    let mut defences: DefencesLevels = Default::default();
    defences.plasma = 1;
    let (res1, res2, def) = fleet::war(
        attackers, Default::default(), defenders, defences, Default::default()
    );
}

#[test]
fn test_war_frigate_vs_blaster() {
    let mut attackers: Fleet = Default::default();
    attackers.frigate = 1;
    let mut defenders: Fleet = Default::default();
    let mut defences: DefencesLevels = Default::default();
    defences.blaster = 19;
    let (res1, res2, def) = fleet::war(
        attackers, Default::default(), defenders, defences, Default::default()
    );
}

#[test]
fn test_war_frigate_vs_beam() {
    let mut attackers: Fleet = Default::default();
    attackers.frigate = 1;
    let mut defenders: Fleet = Default::default();
    let mut defences: DefencesLevels = Default::default();
    defences.beam = 3;
    let (res1, res2, def) = fleet::war(
        attackers, Default::default(), defenders, defences, Default::default()
    );
}

#[test]
fn test_war_frigate_vs_plasma() {
    let mut attackers: Fleet = Default::default();
    attackers.frigate = 5;
    let mut defenders: Fleet = Default::default();
    let mut defences: DefencesLevels = Default::default();
    defences.plasma = 1;
    let (res1, res2, def) = fleet::war(
        attackers, Default::default(), defenders, defences, Default::default()
    );
}

#[test]
fn test_war_armade_vs_frigate() {
    let mut attackers: Fleet = Default::default();
    attackers.armade = 1;
    let mut defenders: Fleet = Default::default();
    defenders.frigate = 4;
    let mut defences: DefencesLevels = Default::default();
    let (res1, res2, def) = fleet::war(
        attackers, Default::default(), defenders, defences, Default::default()
    );
}
#[test]
fn test_war_armade_vs_plasma() {
    let mut attackers: Fleet = Default::default();
    attackers.armade = 5;
    let mut defenders: Fleet = Default::default();
    let mut defences: DefencesLevels = Default::default();
    defences.plasma = 1;
    let (res1, res2, def) = fleet::war(
        attackers, Default::default(), defenders, defences, Default::default()
    );
// assert(res1.is_zero() && res2.is_zero(), 'wrong assert 1');
}
#[test]
fn test_war_armade_vs_astral() {
    let mut attackers: Fleet = Default::default();
    attackers.armade = 1;
    let mut defenders: Fleet = Default::default();
    let mut defences: DefencesLevels = Default::default();
    defences.astral = 10;
    let (res1, res2, def) = fleet::war(
        attackers, Default::default(), defenders, defences, Default::default()
    );
// assert(res1.is_zero() && res2.is_zero(), 'wrong assert 1');
}

#[test]
fn test_cargo_speed() {
    let mut fleet: Fleet = Default::default();
    let mut techs: TechLevels = Default::default();
    fleet.carrier = 1;
    assert(fleet::get_fleet_speed(fleet, techs) == 5000, 'wrong_speed 5000');
    techs.combustion = 1;
    assert(fleet::get_fleet_speed(fleet, techs) == 5500, 'wrong_speed 5500');
    techs.combustion = 9;
    assert(fleet::get_fleet_speed(fleet, techs) == 9500, 'wrong_speed 9500');
    techs.thrust = 4;
    assert(fleet::get_fleet_speed(fleet, techs) == 10000, 'wrong_speed 10000');
    techs.thrust = 8;
    assert(fleet::get_fleet_speed(fleet, techs) == 18000, 'wrong_speed 18000');
}

#[test]
fn test_scraper_speed() {
    let mut fleet: Fleet = Default::default();
    let mut techs: TechLevels = Default::default();
    fleet.scraper = 1;
    assert(fleet::get_fleet_speed(fleet, techs) == 2000, 'wrong_speed');
    techs.combustion = 1;
    assert(fleet::get_fleet_speed(fleet, techs) == 2200, 'wrong_speed');
    techs.combustion = 9;
    assert(fleet::get_fleet_speed(fleet, techs) == 3800, 'wrong_speed');
}

#[test]
fn test_sparrow_speed() {
    let mut fleet: Fleet = Default::default();
    let mut techs: TechLevels = Default::default();
    fleet.sparrow = 1;
    assert(fleet::get_fleet_speed(fleet, techs) == 12500, 'wrong_speed');
    techs.combustion = 1;
    assert(fleet::get_fleet_speed(fleet, techs) == 13750, 'wrong_speed');
    techs.combustion = 9;
    assert(fleet::get_fleet_speed(fleet, techs) == 23750, 'wrong_speed');
}

#[test]
fn test_frigate_speed() {
    let mut fleet: Fleet = Default::default();
    let mut techs: TechLevels = Default::default();
    fleet.frigate = 1;
    techs.thrust = 4;
    assert(fleet::get_fleet_speed(fleet, techs) == 15000, 'wrong_speed');
    techs.thrust = 5;
    assert(fleet::get_fleet_speed(fleet, techs) == 18000, 'wrong_speed');
    techs.thrust = 9;
    assert(fleet::get_fleet_speed(fleet, techs) == 30000, 'wrong_speed');
}

#[test]
fn test_armade_speed() {
    let mut fleet: Fleet = Default::default();
    let mut techs: TechLevels = Default::default();
    fleet.armade = 1;
    techs.spacetime = 3;
    assert(fleet::get_fleet_speed(fleet, techs) == 10000, 'wrong_speed');
    techs.spacetime = 5;
    assert(fleet::get_fleet_speed(fleet, techs) == 16000, 'wrong_speed');
    techs.spacetime = 9;
    assert(fleet::get_fleet_speed(fleet, techs) == 28000, 'wrong_speed');
    techs.spacetime = 11;
    assert(fleet::get_fleet_speed(fleet, techs) == 34000, 'wrong_speed');
}

#[test]
fn test_mixed_speed() {
    let mut fleet: Fleet = Default::default();
    let mut techs: TechLevels = Default::default();
    fleet.carrier = 1;
    fleet.frigate = 1;
    fleet.armade = 1;
    techs.thrust = 4;
    techs.spacetime = 4;
    assert(fleet::get_fleet_speed(fleet, techs) == 10000, 'wrong_speed');
}

#[test]
fn test_basic_flight_time() {
    let mut fleet: Fleet = Default::default();
    assert(fleet::get_flight_time(30000, 1005, 100) == 2035, 'wrong assert #1');
    assert(fleet::get_flight_time(15000, 1005, 100) == 2874, 'wrong assert #2');
    assert(fleet::get_flight_time(10000, 1005, 100) == 3518, 'wrong assert #3');
    assert(fleet::get_flight_time(4000, 1005, 100) == 5557, 'wrong assert #4');
    assert(fleet::get_flight_time(2000, 1005, 100) == 7855, 'wrong assert #5');
    assert(fleet::get_flight_time(2000, 5, 100) == 563, 'wrong assert #6');
}

#[test]
fn test_long_flight_time() {
    let mut fleet: Fleet = Default::default();
    assert(fleet::get_flight_time(30000, 21605, 100) == 9402, 'wrong assert #1');
    assert(fleet::get_flight_time(15000, 21605, 100) == 13293, 'wrong assert #5');
    assert(fleet::get_flight_time(10000, 21605, 100) == 16278, 'wrong assert #5');
    assert(fleet::get_flight_time(4000, 21605, 100) == 25732, 'wrong assert #5');
    assert(fleet::get_flight_time(2000, 21605, 100) == 36387, 'wrong assert #5');
}

#[test]
fn test_speed_modifier_75() {
    let mut fleet: Fleet = Default::default();
    assert(fleet::get_flight_time(30000, 21605, 75) == 12536, 'wrong assert #1');
    assert(fleet::get_flight_time(15000, 21605, 75) == 17724, 'wrong assert #5');
    assert(fleet::get_flight_time(10000, 21605, 75) == 21704, 'wrong assert #5');
    assert(fleet::get_flight_time(4000, 21605, 75) == 34310, 'wrong assert #5');
    assert(fleet::get_flight_time(2000, 21605, 75) == 48516, 'wrong assert #6');
}

#[test]
fn test_speed_modifier_50() {
    let mut fleet: Fleet = Default::default();
    assert(fleet::get_flight_time(30000, 21605, 50) == 18805, 'wrong assert #1');
    assert(fleet::get_flight_time(15000, 21605, 50) == 26586, 'wrong assert #5');
    assert(fleet::get_flight_time(10000, 21605, 50) == 32556, 'wrong assert #5');
    assert(fleet::get_flight_time(4000, 21605, 50) == 51465, 'wrong assert #5');
    assert(fleet::get_flight_time(2000, 21605, 50) == 72774, 'wrong assert #5');
}

#[test]
fn test_distance() {
    let mut start: PlanetPosition = Default::default();
    let mut end: PlanetPosition = Default::default();

    start.system = 1;
    start.orbit = 1;
    end.system = 1;
    end.orbit = 2;
    assert(fleet::get_distance(start, end) == 1005, 'wrong distance 1005');

    end.orbit = 10;
    assert(fleet::get_distance(start, end) == 1045, 'wrong distance 1045');

    end.orbit = 1;
    assert(fleet::get_distance(start, end) == 5, 'wrong distance 5');

    start.system = 1;
    end.system = 2;
    assert(fleet::get_distance(start, end) == 2795, 'wrong distance 2795');

    start.system = 2;
    end.system = 1;
    assert(fleet::get_distance(start, end) == 2795, 'wrong distance 2795');

    start.system = 5;
    end.system = 241;
    assert(fleet::get_distance(start, end) == 25120, 'wrong distance 25120');

    start.system = 241;
    end.system = 5;
    assert(fleet::get_distance(start, end) == 25120, 'wrong distance 25120');
}

#[test]
fn test_fuel_consumption() {
    let mut fleet: Fleet = Default::default();
    fleet.carrier = 100;
    // fleet.armade = 1;
    fleet::get_fuel_consumption(fleet, 2700, 100).print();
}

#[test]
fn test_get_debris() {
    let mut before: Fleet = Default::default();
    let mut after: Fleet = Default::default();
    before.carrier = 10;
    after.carrier = 0;
    let res = fleet::get_debris(before, after, 10);
}

#[test]
fn test_calculate_fleet_loss() {
    let loss = fleet::calculate_fleet_loss(60);
    assert(loss == 1, 'wrong #1');

    let loss = fleet::calculate_fleet_loss(350);
    assert(loss == 11, 'wrong #2');

    let loss = fleet::calculate_fleet_loss(600);
    assert(loss == 18, 'wrong #3');

    let loss = fleet::calculate_fleet_loss(1800);
    assert(loss == 45, 'wrong #4');

    let loss = fleet::calculate_fleet_loss(2700);
    assert(loss == 59, 'wrong #5');

    let loss = fleet::calculate_fleet_loss(3600);
    assert(loss == 69, 'wrong #6');

    let loss = fleet::calculate_fleet_loss(5400);
    assert(loss == 83, 'wrong #7');

    let loss = fleet::calculate_fleet_loss(7200);
    assert(loss == 90, 'wrong #8');
}

#[test]
fn test_decay_fleet() {
    let mut fleet: Fleet = Default::default();
    fleet.carrier = 45;
    fleet.scraper = 128;
    fleet.sparrow = 555;
    fleet.frigate = 122;
    fleet.armade = 2;

    let res = fleet::decay_fleet(fleet, 5);
    let res = fleet::decay_fleet(fleet, 25);
    let res = fleet::decay_fleet(fleet, 65);
    let res = fleet::decay_fleet(fleet, 85);
    let res = fleet::decay_fleet(fleet, 95);
}

#[test]
fn test_load_resources() {
    let mut resources: ERC20s = Default::default();
    resources.steel = 100_000;
    resources.quartz = 100_000;
    resources.tritium = 100_000;
    let storage = 30_000;
    let loaded = fleet::load_resources(resources, storage);
}

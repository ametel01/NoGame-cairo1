use starknet::testing::cheatcode;
use starknet::{ContractAddress, contract_address_const, get_block_timestamp, get_contract_address};

use snforge_std::{start_prank, start_warp, CheatTarget};

use nogame::game::interface::{INoGameDispatcher, INoGameDispatcherTrait};
use nogame::libraries::types::{
    ERC20s, EnergyCost, TechLevels, TechsCost, ShipsLevels, ShipsCost, DefencesLevels, DefencesCost,
    Fleet, BuildType, MissionCategory
};
use tests::utils::{
    E18, HOUR, DAY, Dispatchers, ACCOUNT1, ACCOUNT2, ACCOUNT3, ACCOUNT4, ACCOUNT5, init_game,
    set_up, DEPLOYER, warp_multiple, advance_game_state, build_basic_mines, init_storage
};

#[test]
fn test_get_current_planet_price() {
    let dsp = set_up();
    init_game(dsp);

    (dsp.game.get_current_planet_price() == 11999999999999998, 'wrong price-1');
    start_prank(CheatTarget::One(dsp.game.contract_address), ACCOUNT1());
    dsp.game.generate_planet();

    (dsp.game.get_current_planet_price() == 12060150250085595, 'wrong price-1');
    start_prank(CheatTarget::One(dsp.game.contract_address), ACCOUNT2());
    dsp.game.generate_planet();

    (dsp.game.get_current_planet_price() == 12120602004610750, 'wrong price-1');
    start_prank(CheatTarget::One(dsp.game.contract_address), ACCOUNT3());
    dsp.game.generate_planet();

    start_warp(CheatTarget::All, DAY * 13);

    (dsp.game.get_current_planet_price() == 6359225859946644, 'wrong price-1');
    start_prank(CheatTarget::One(dsp.game.contract_address), ACCOUNT4());
    dsp.game.generate_planet();

    (dsp.game.get_current_planet_price() == 6391101612214528, 'wrong price-1');
    start_prank(CheatTarget::One(dsp.game.contract_address), ACCOUNT5());
    dsp.game.generate_planet();
}

#[test]
fn test_get_number_of_planets() {
    let dsp = set_up();
    init_game(dsp);
    start_prank(CheatTarget::One(dsp.game.contract_address), ACCOUNT1());
    dsp.game.generate_planet();
    assert(dsp.game.get_number_of_planets() == 1, 'wrong n planets');
}

#[test]
fn test_get_planet_position() {
    let dsp = set_up();
    init_game(dsp);
    start_prank(CheatTarget::One(dsp.game.contract_address), ACCOUNT1());

    assert(dsp.game.get_planet_position(1).is_zero(), 'wrong assert #1');
}

#[test]
fn test_get_debris_field() {
    let dsp = set_up();
    init_game(dsp);
    start_prank(CheatTarget::One(dsp.game.contract_address), ACCOUNT1());
    dsp.game.generate_planet();
    start_prank(CheatTarget::One(dsp.game.contract_address), ACCOUNT2());
    dsp.game.generate_planet();

    assert(dsp.game.get_debris_field(1).is_zero(), 'wrong debris field');
    assert(dsp.game.get_debris_field(2).is_zero(), 'wrong debris field');

    start_prank(CheatTarget::One(dsp.game.contract_address), ACCOUNT1());
    init_storage(dsp, 1);
    dsp.game.process_ship_build(BuildType::Carrier(()), 100);

    start_prank(CheatTarget::One(dsp.game.contract_address), ACCOUNT2());
    init_storage(dsp, 2);
    dsp.game.process_defence_build(BuildType::Astral(()), 5);

    start_prank(CheatTarget::One(dsp.game.contract_address), ACCOUNT1());
    let mut fleet: Fleet = Default::default();
    let position = dsp.game.get_planet_position(2);
    fleet.carrier = 100;
    dsp.game.send_fleet(fleet, position, MissionCategory::ATTACK, 100, 0);
    warp_multiple(dsp.game.contract_address, get_contract_address(), get_block_timestamp() + DAY);
    dsp.game.attack_planet(1);

    assert(dsp.game.get_debris_field(1).is_zero(), 'wrong debris field');
    let debris = dsp.game.get_debris_field(2);
    assert(debris.steel == 66666 && debris.quartz == 66666, 'wrong debris field');
}

#[test]
fn test_get_spendable_resources() {
    let dsp = set_up();
    init_game(dsp);
    start_prank(CheatTarget::One(dsp.game.contract_address), ACCOUNT1());
    dsp.game.generate_planet();

    let spendable = dsp.game.get_spendable_resources(1);
    assert(spendable.steel == 500, 'wrong spendable');
    assert(spendable.quartz == 300, 'wrong spendable ');
    assert(spendable.tritium == 100, 'wrong spendable ');
}

#[test]
fn test_get_collectible_resources() {
    let dsp = set_up();
    init_game(dsp);
    start_prank(CheatTarget::One(dsp.game.contract_address), ACCOUNT1());
    dsp.game.generate_planet();
    build_basic_mines(dsp.game);

    start_warp(CheatTarget::All, get_block_timestamp() + HOUR / 6);
    let collectible = dsp.game.get_collectible_resources(1);
    assert(collectible.steel == 19, 'wrong collectible ');
    assert(collectible.quartz == 19, 'wrong collectible ');
    assert(collectible.tritium == 7, 'wrong collectible ');
}

#[test]
fn test_get_planet_points() {
    let dsp = set_up();
    init_game(dsp);
    start_prank(CheatTarget::One(dsp.game.contract_address), ACCOUNT1());
    dsp.game.generate_planet();
    start_prank(CheatTarget::One(dsp.game.contract_address), ACCOUNT2());
    dsp.game.generate_planet();
    build_basic_mines(dsp.game);
    start_prank(CheatTarget::One(dsp.game.contract_address), ACCOUNT3());
    dsp.game.generate_planet();
    build_basic_mines(dsp.game);
    advance_game_state(dsp.game);

    (dsp.game.get_planet_points(1) == 0, 'wrong points 0');
    (dsp.game.get_planet_points(2) == 5, 'wrong points 5');
    (dsp.game.get_planet_points(3) == 972, 'wrong points 972');
}


// use core::testing::get_available_gas;
// use starknet::testing::cheatcode;
// use starknet::info::{get_contract_address, get_block_timestamp};
// use starknet::{ContractAddress, contract_address_const};
// use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};

// use snforge_std::{declare, ContractClassTrait, start_prank, start_warp,  CheatTarget};

// use nogame::game::interface::{INoGameDispatcher, INoGameDispatcherTrait};
// use nogame::libraries::types::{
//     ERC20s, EnergyCost, TechLevels, TechsCost, ShipsLevels, ShipsCost, DefencesLevels, DefencesCost
// };
// use tests::utils::{E18, HOUR, Dispatchers, ACCOUNT1, ACCOUNT2, DEPLOYER, init_game, set_up};

// #[test]
// fn test_carrier_build() {
//     let dsp = set_up();
//     init_game(dsp);

//     start_prank(CheatTarget::One(dsp.game.contract_address), ACCOUNT1());
//     dsp.game.generate_planet();

//     dsp.game.energy_plant_upgrade(1);
//     dsp.game.tritium_mine_upgrade(1);
//     start_warp(CheatTarget::All, HOUR * 2400000);
//     dsp.game.dockyard_upgrade(1);
//     dsp.game.dockyard_upgrade(1);
//     dsp.game.lab_upgrade(1);
//     dsp.game.energy_innovation_upgrade(1);
//     dsp.game.combustive_engine_upgrade(1);
//     dsp.game.combustive_engine_upgrade(1);

//     dsp.game.carrier_build(10);
//     let ships = dsp.game.get_ships_levels(1);
//     assert(ships.carrier == 10, 'wrong carrier level');
// }

// #[test]
// fn test_carrier_build_fails_dockyard_level() { // TODO
//     assert(0 == 0, 'todo');
// }

// #[test]
// fn test_carrier_build_fails_combustion_level() { // TODO
//     assert(0 == 0, 'todo');
// }

// #[test]
// fn test_celestia_build() {
//     let dsp = set_up();
//     init_game(dsp);

//     start_prank(CheatTarget::One(dsp.game.contract_address), ACCOUNT1());
//     dsp.game.generate_planet();

//     dsp.game.energy_plant_upgrade(1);
//     dsp.game.tritium_mine_upgrade(1);
//     start_warp(CheatTarget::All, HOUR * 2400000);
//     dsp.game.dockyard_upgrade(1);
//     dsp.game.lab_upgrade(1);
//     dsp.game.energy_innovation_upgrade(1);
//     dsp.game.combustive_engine_upgrade(1);

//     dsp.game.celestia_build(10);
//     let ships = dsp.game.get_ships_levels(1);
// }

// #[test]
// fn test_celestia_build_fails_dockyard_level() { // TODO
//     assert(0 == 0, 'todo');
// }

// #[test]
// fn test_celestia_build_fails_combustion_level() { // TODO
//     assert(0 == 0, 'todo');
// }

// #[test]
// fn test_sparrow_build() {
//     let dsp = set_up();
//     init_game(dsp);

//     start_prank(CheatTarget::One(dsp.game.contract_address), ACCOUNT1());
//     dsp.game.generate_planet();

//     dsp.game.energy_plant_upgrade(1);
//     dsp.game.tritium_mine_upgrade(1);
//     start_warp(CheatTarget::All, HOUR * 2400000);
//     dsp.game.dockyard_upgrade(1);
//     dsp.game.lab_upgrade(1);
//     dsp.game.energy_innovation_upgrade(1);
//     dsp.game.combustive_engine_upgrade(1);

//     dsp.game.sparrow_build(10);
//     let ships = dsp.game.get_ships_levels(1);
//     assert(ships.sparrow == 10, 'wrong sparrow level');
// }

// #[test]
// fn test_sparrow_build_fails_dockyard_level() { // TODO
//     assert(0 == 0, 'todo');
// }

// #[test]
// fn test_sparrow_build_fails_combustion_level() { // TODO
//     assert(0 == 0, 'todo');
// }

// #[test]
// fn test_scraper_build() {
//     let dsp = set_up();
//     init_game(dsp);

//     start_prank(CheatTarget::One(dsp.game.contract_address), ACCOUNT1());
//     dsp.game.generate_planet();

//     dsp.game.energy_plant_upgrade(1);
//     dsp.game.tritium_mine_upgrade(1);
//     start_warp(CheatTarget::All, HOUR * 2400000);
//     dsp.game.dockyard_upgrade(4);
//     dsp.game.lab_upgrade(1);
//     dsp.game.energy_innovation_upgrade(1);
//     dsp.game.combustive_engine_upgrade(6);
//     dsp.game.lab_upgrade(5);
//     dsp.game.energy_innovation_upgrade(2);
//     dsp.game.shield_tech_upgrade(2);

//     dsp.game.scraper_build(10);
//     let ships = dsp.game.get_ships_levels(1);
//     assert(ships.scraper == 10, 'wrong scraper level');
// }

// #[test]
// fn test_scraper_build_fails_dockyard_level() { // TODO
//     assert(0 == 0, 'todo');
// }

// #[test]
// fn test_scraper_build_fails_combustion_level() { // TODO
//     assert(0 == 0, 'todo');
// }

// #[test]
// fn test_scraper_build_fails_shield_level() { // TODO
//     assert(0 == 0, 'todo');
// }

// #[test]
// fn test_frigate_build() {
//     let dsp = set_up();
//     init_game(dsp);

//     start_prank(CheatTarget::One(dsp.game.contract_address), ACCOUNT1());
//     dsp.game.generate_planet();

//     dsp.game.energy_plant_upgrade(1);
//     dsp.game.tritium_mine_upgrade(1);
//     start_warp(CheatTarget::All, HOUR * 2400000);
//     dsp.game.dockyard_upgrade(5);
//     dsp.game.lab_upgrade(4);
//     dsp.game.energy_innovation_upgrade(4);
//     dsp.game.beam_technology_upgrade(5);
//     dsp.game.ion_systems_upgrade(2);
//     dsp.game.thrust_propulsion_upgrade(4);

//     dsp.game.frigate_build(10);
//     let ships = dsp.game.get_ships_levels(1);
//     assert(ships.frigate == 10, 'wrong frigate level');
// }

// #[test]
// fn test_frigate_build_fails_dockyard_level() { // TODO
//     assert(0 == 0, 'todo');
// }

// #[test]
// fn test_frigate_build_fails_ion_level() { // TODO
//     assert(0 == 0, 'todo');
// }

// #[test]
// fn test_frigate_build_fails_thrust_level() { // TODO
//     assert(0 == 0, 'todo');
// }

// #[test]
// fn test_armade_build() {
//     let dsp = set_up();
//     init_game(dsp);

//     start_prank(CheatTarget::One(dsp.game.contract_address), ACCOUNT1());
//     dsp.game.generate_planet();

//     dsp.game.energy_plant_upgrade(1);
//     dsp.game.tritium_mine_upgrade(1);
//     start_warp(CheatTarget::All, HOUR * 2400000);
//     dsp.game.dockyard_upgrade(7);
//     dsp.game.lab_upgrade(7);
//     dsp.game.energy_innovation_upgrade(5);
//     dsp.game.shield_tech_upgrade(5);
//     dsp.game.spacetime_warp_upgrade(3);
//     dsp.game.warp_drive_upgrade(4);

//     dsp.game.armade_build(10);
//     let ships = dsp.game.get_ships_levels(1);
//     assert(ships.armade == 10, 'wrong armade level');
// }

// #[test]
// fn test_armade_build_fails_dockyard_level() { // TODO
//     assert(0 == 0, 'todo');
// }

// #[test]
// fn test_armade_build_fails_warp_level() { // TODO
//     assert(0 == 0, 'todo');
// }



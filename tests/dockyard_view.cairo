use nogame::game::interface::{INoGameDispatcher, INoGameDispatcherTrait};
use nogame::libraries::types::{
    ERC20s, EnergyCost, TechLevels, TechsCost, ShipsLevels, ShipsCost, DefencesLevels, DefencesCost
};
use nogame::storage::storage::{IStorageDispatcher, IStorageDispatcherTrait};
use nogame::token::erc721::interface::{IERC721NoGameDispatcher, IERC721NoGameDispatcherTrait};
use snforge_std::PrintTrait;

use snforge_std::{start_prank, start_warp, CheatTarget};
use starknet::info::get_contract_address;
use starknet::testing::cheatcode;
use starknet::{ContractAddress, contract_address_const};
use tests::utils::{E18, HOUR, Dispatchers, ACCOUNT1, ACCOUNT2, init_game, set_up};

#[test]
fn test_get_ships_levels() {
    let dsp = set_up();
    init_game(dsp);
    start_prank(CheatTarget::One(dsp.nogame.contract_address), ACCOUNT1());
    dsp.nogame.generate_planet();

    let ships = dsp.storage.get_ships_levels(1);
    assert(ships.carrier == 0, 'wrong carrier`');
    assert(ships.scraper == 0, 'wrong scraper');
    assert(ships.sparrow == 0, 'wrong sparrow');
    assert(ships.frigate == 0, 'wrong frigate');
    assert(ships.armade == 0, 'wrong armade');
}

#[test]
fn test_get_celestia_available() { // TODO
    assert(0 == 0, 'todo');
}

use starknet::testing::cheatcode;
use starknet::info::get_contract_address;
use starknet::{ContractAddress, contract_address_const};
use snforge_std::{start_prank, start_warp, CheatTarget};

use nogame::game::interface::{INoGameDispatcher, INoGameDispatcherTrait};
use nogame::libraries::compounds::{Production, Compounds};
use nogame::libraries::types::{CompoundsLevels, Names};
use tests::utils::{
    E18, HOUR, Dispatchers, ACCOUNT1, ACCOUNT2, ACCOUNT3, ACCOUNT4, ACCOUNT5, init_game, set_up,
};
use nogame::game::main::NoGame;
use nogame::game::main::NoGame::compounds_levelContractMemberStateTrait;

#[test]
fn test_get_compounds_levels() {
    let dsp = set_up();
    init_game(dsp);
    start_prank(CheatTarget::One(dsp.game.contract_address), ACCOUNT1());
    dsp.game.generate_planet();

    let compounds = dsp.game.get_compounds_levels(1);
    assert(compounds.steel == 0, 'wrong steel lev');
    assert(compounds.quartz == 0, 'wrong quartz lev');
    assert(compounds.tritium == 0, 'wrong quartz lev');
    assert(compounds.energy == 0, 'wrong energy lev');
    assert(compounds.lab == 0, 'wrong energy lev');
    assert(compounds.dockyard == 0, 'wrong energy lev');
}

use array::ArrayTrait;
use starknet::{
    ContractAddress, contract_address_const, get_block_timestamp, get_contract_address,
    get_caller_address, class_hash::ClassHash
};
use openzeppelin::token::erc20::interface::{IERC20CamelDispatcher, IERC20CamelDispatcherTrait};
use nogame_fixed::f128::types::{Fixed, FixedTrait, ONE_u128 as ONE};

use nogame::game::interface::{INoGameDispatcher, INoGameDispatcherTrait};
use nogame::libraries::types::{PRICE, UpgradeType, BuildType, Names, ERC20s};
use nogame::token::erc20::interface::{IERC20NoGameDispatcher, IERC20NoGameDispatcherTrait};
use nogame::token::erc20::erc20_ng::ERC20NoGame;
use nogame::token::erc20::erc20::ERC20;
use nogame::token::erc721::interface::{IERC721NoGameDispatcher, IERC721NoGameDispatcherTrait};

use snforge_std::{
    declare, ContractClassTrait, start_warp, start_prank, stop_prank,  CheatTarget,
    store, map_entry_address
};

const E18: u128 = 1_000_000_000_000_000_000;
const ETH_SUPPLY: felt252 = 1_000_000_000_000_000_000_000;
const HOUR: u64 = 3_600;
const DAY: u64 = 86_400;
const WEEK: u64 = 604_800;
const YEAR: u64 = 31_557_600;

#[derive(Copy, Drop, Serde)]
struct Dispatchers {
    erc721: IERC721NoGameDispatcher,
    steel: IERC20NoGameDispatcher,
    quartz: IERC20NoGameDispatcher,
    tritium: IERC20NoGameDispatcher,
    eth: IERC20CamelDispatcher,
    game: INoGameDispatcher,
}

fn DEPLOYER() -> ContractAddress {
    contract_address_const::<'DEPLOYER'>()
}
fn ACCOUNT1() -> ContractAddress {
    contract_address_const::<1>()
}
fn ACCOUNT2() -> ContractAddress {
    contract_address_const::<2>()
}
fn ACCOUNT3() -> ContractAddress {
    contract_address_const::<3>()
}
fn ACCOUNT4() -> ContractAddress {
    contract_address_const::<4>()
}
fn ACCOUNT5() -> ContractAddress {
    contract_address_const::<5>()
}

fn set_up() -> Dispatchers {
    let contract = declare('NoGame');
    let calldata: Array<felt252> = array![];
    let _game = contract.deploy(@calldata).expect('failed nogame');

    let contract = declare('ERC721NoGame');
    let calldata: Array<felt252> = array!['nogame-planet', 'NGPL', _game.into(), DEPLOYER().into()];
    let _erc721 = contract.deploy(@calldata).expect('failed erc721');

    let contract = declare('ERC20NoGame');
    let calldata: Array<felt252> = array!['Nogame Steel', 'NGST', _game.into()];
    let _steel = contract.deploy(@calldata).expect('failed steel');

    let calldata: Array<felt252> = array!['Nogame Quartz', 'NGQZ', _game.into()];
    let _quartz = contract.deploy(@calldata).expect('failed quartz');

    let calldata: Array<felt252> = array!['Nogame Tritium', 'NGTR', _game.into()];
    let _tritium = contract.deploy(@calldata).expect('failed tritium');

    let contract = declare('ERC20');
    let calldata: Array<felt252> = array!['ETHER', 'ETH', ETH_SUPPLY, 0, DEPLOYER().into()];
    let _eth = contract.deploy(@calldata).expect('failed to deploy eth');

    Dispatchers {
        erc721: IERC721NoGameDispatcher { contract_address: _erc721 },
        steel: IERC20NoGameDispatcher { contract_address: _steel },
        quartz: IERC20NoGameDispatcher { contract_address: _quartz },
        tritium: IERC20NoGameDispatcher { contract_address: _tritium },
        eth: IERC20CamelDispatcher { contract_address: _eth },
        game: INoGameDispatcher { contract_address: _game }
    }
}

fn init_game(dsp: Dispatchers) {
    start_prank(CheatTarget::All, DEPLOYER());
    dsp
        .game
        .initializer(
            dsp.erc721.contract_address,
            dsp.steel.contract_address,
            dsp.quartz.contract_address,
            dsp.tritium.contract_address,
            dsp.eth.contract_address,
            DEPLOYER(),
            1,
            ONE,
            false
        );
    start_prank(CheatTarget::One(dsp.eth.contract_address), DEPLOYER());
    dsp.eth.transfer(ACCOUNT1(), (10 * E18).into());
    dsp.eth.transfer(ACCOUNT2(), (10 * E18).into());
    dsp.eth.transfer(ACCOUNT3(), (10 * E18).into());
    dsp.eth.transfer(ACCOUNT4(), (10 * E18).into());
    dsp.eth.transfer(ACCOUNT5(), (10 * E18).into());
    stop_prank(CheatTarget::One(dsp.eth.contract_address));

    start_prank(CheatTarget::One(dsp.eth.contract_address), ACCOUNT1());
    dsp.eth.approve(dsp.game.contract_address, (2 * E18).into());
    stop_prank(CheatTarget::One(dsp.eth.contract_address));

    start_prank(CheatTarget::One(dsp.eth.contract_address), ACCOUNT2());
    dsp.eth.approve(dsp.game.contract_address, (2 * E18).into());
    stop_prank(CheatTarget::One(dsp.eth.contract_address));

    start_prank(CheatTarget::One(dsp.eth.contract_address), ACCOUNT3());
    dsp.eth.approve(dsp.game.contract_address, (2 * E18).into());
    stop_prank(CheatTarget::One(dsp.eth.contract_address));

    start_prank(CheatTarget::One(dsp.eth.contract_address), ACCOUNT4());
    dsp.eth.approve(dsp.game.contract_address, (2 * E18).into());
    stop_prank(CheatTarget::One(dsp.eth.contract_address));

    start_prank(CheatTarget::One(dsp.eth.contract_address), ACCOUNT5());
    dsp.eth.approve(dsp.game.contract_address, (2 * E18).into());
    stop_prank(CheatTarget::One(dsp.eth.contract_address));
    start_prank(CheatTarget::One(dsp.erc721.contract_address), dsp.game.contract_address);
    start_prank(CheatTarget::One(dsp.steel.contract_address), dsp.game.contract_address);
    start_prank(CheatTarget::One(dsp.quartz.contract_address), dsp.game.contract_address);
    start_prank(CheatTarget::One(dsp.tritium.contract_address), dsp.game.contract_address);
}

#[test]
fn test_deploy_and_init() {
    let dsp: Dispatchers = set_up();
    init_game(dsp);
    start_prank(CheatTarget::All, dsp.game.contract_address);
    dsp.eth.transferFrom(ACCOUNT1(), DEPLOYER(), 1.into());
}

// builds:
// - steel_mine: 3
// - quartz_mine: 4
// - tritium_mine: 7
// - energy_plant: 8
fn build_basic_mines(game: INoGameDispatcher) {
    warp_multiple(game.contract_address, get_contract_address(), get_block_timestamp() + YEAR * 2);
    game.process_compound_upgrade(UpgradeType::EnergyPlant(()), 8);
    game.process_compound_upgrade(UpgradeType::SteelMine(()), 3);
    game.process_compound_upgrade(UpgradeType::QuartzMine(()), 4);
    game.process_compound_upgrade(UpgradeType::TritiumMine(()), 6);
}

fn advance_game_state(game: INoGameDispatcher) {
    warp_multiple(game.contract_address, get_contract_address(), get_block_timestamp() + YEAR * 3);
    game.process_compound_upgrade(UpgradeType::Dockyard(()), 8);
    game.process_compound_upgrade(UpgradeType::Lab(()), 7);
    game.process_tech_upgrade(UpgradeType::EnergyTech(()), 8);
    game.process_tech_upgrade(UpgradeType::Combustion(()), 6);
    game.process_tech_upgrade(UpgradeType::BeamTech(()), 10);
    game.process_tech_upgrade(UpgradeType::Shield(()), 5);
    game.process_tech_upgrade(UpgradeType::Spacetime(()), 3);
    game.process_tech_upgrade(UpgradeType::Warp(()), 4);
    game.process_tech_upgrade(UpgradeType::Ion(()), 5);
    game.process_tech_upgrade(UpgradeType::Thrust(()), 4);
    game.process_tech_upgrade(UpgradeType::PlasmaTech(()), 7);
    game.process_tech_upgrade(UpgradeType::Weapons(()), 3);
}

fn init_storage(dsp: Dispatchers, planet_id: u32) {
    store(
        dsp.game.contract_address,
        map_entry_address(
            selector!("compounds_level"), // Providing variable name
            array![planet_id.into(), Names::STEEL].span(), // Providing mapping key 
        ),
        array![20].span()
    );
    store(
        dsp.game.contract_address,
        map_entry_address(
            selector!("compounds_level"), // Providing variable name
            array![planet_id.into(), Names::QUARTZ].span(), // Providing mapping key 
        ),
        array![20].span()
    );
    store(
        dsp.game.contract_address,
        map_entry_address(
            selector!("compounds_level"), // Providing variable name
            array![planet_id.into(), Names::TRITIUM].span(), // Providing mapping key 
        ),
        array![20].span()
    );
    store(
        dsp.game.contract_address,
        map_entry_address(
            selector!("compounds_level"), // Providing variable name
            array![planet_id.into(), Names::ENERGY_PLANT].span(), // Providing mapping key 
        ),
        array![30].span()
    );
    store(
        dsp.game.contract_address,
        map_entry_address(
            selector!("compounds_level"), // Providing variable name
            array![planet_id.into(), Names::LAB].span(), // Providing mapping key 
        ),
        array![10].span()
    );
    store(
        dsp.game.contract_address,
        map_entry_address(
            selector!("compounds_level"), // Providing variable name
            array![planet_id.into(), Names::DOCKYARD].span(), // Providing mapping key 
        ),
        array![8].span()
    );
    store(
        dsp.game.contract_address,
        map_entry_address(
            selector!("techs_level"), // Providing variable name
            array![planet_id.into(), Names::ENERGY_TECH].span(), // Providing mapping key 
        ),
        array![8].span()
    );
    store(
        dsp.game.contract_address,
        map_entry_address(
            selector!("techs_level"), // Providing variable name
            array![planet_id.into(), Names::COMBUSTION].span(), // Providing mapping key 
        ),
        array![6].span()
    );
    store(
        dsp.game.contract_address,
        map_entry_address(
            selector!("techs_level"), // Providing variable name
            array![planet_id.into(), Names::BEAM_TECH].span(), // Providing mapping key 
        ),
        array![10].span()
    );
    store(
        dsp.game.contract_address,
        map_entry_address(
            selector!("techs_level"), // Providing variable name
            array![planet_id.into(), Names::SHIELD].span(), // Providing mapping key 
        ),
        array![6].span()
    );
    store(
        dsp.game.contract_address,
        map_entry_address(
            selector!("techs_level"), // Providing variable name
            array![planet_id.into(), Names::SPACETIME].span(), // Providing mapping key 
        ),
        array![3].span()
    );
    store(
        dsp.game.contract_address,
        map_entry_address(
            selector!("techs_level"), // Providing variable name
            array![planet_id.into(), Names::WARP].span(), // Providing mapping key 
        ),
        array![4].span()
    );
    store(
        dsp.game.contract_address,
        map_entry_address(
            selector!("techs_level"), // Providing variable name
            array![planet_id.into(), Names::ION].span(), // Providing mapping key 
        ),
        array![5].span()
    );
    store(
        dsp.game.contract_address,
        map_entry_address(
            selector!("techs_level"), // Providing variable name
            array![planet_id.into(), Names::THRUST].span(), // Providing mapping key 
        ),
        array![4].span()
    );
    store(
        dsp.game.contract_address,
        map_entry_address(
            selector!("techs_level"), // Providing variable name
            array![planet_id.into(), Names::PLASMA_TECH].span(), // Providing mapping key 
        ),
        array![7].span()
    );
    store(
        dsp.game.contract_address,
        map_entry_address(
            selector!("techs_level"), // Providing variable name
            array![planet_id.into(), Names::WEAPONS].span(), // Providing mapping key 
        ),
        array![4].span()
    );
    store(
        dsp.game.contract_address,
        map_entry_address(
            selector!("techs_level"), // Providing variable name
            array![planet_id.into(), Names::EXOCRAFT].span(), // Providing mapping key 
        ),
        array![5].span()
    );
    store(
        dsp.game.contract_address,
        map_entry_address(
            selector!("resources_spent"), // Providing variable name
            array![planet_id.into()].span(), // Providing mapping key 
        ),
        array![1_000_000_000].span()
    );
    warp_multiple(dsp.game.contract_address, get_contract_address(), get_block_timestamp() + WEEK);
    dsp.game.collect_resources();
}


fn warp_multiple(a: ContractAddress, b: ContractAddress, time: u64) {
    start_warp(CheatTarget::All, time);
    start_warp(CheatTarget::All, time);
}

fn declare_upgradable() -> ClassHash {
    declare('NoGameUpgraded').class_hash
}

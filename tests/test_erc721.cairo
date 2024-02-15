use core::result::ResultTrait;
use snforge_std::{declare, ContractClassTrait, start_prank,  CheatTarget};

use nogame::token::erc721::interface::{IERC721NoGameDispatcher, IERC721NoGameDispatcherTrait};
use tests::utils::{DEPLOYER, ACCOUNT1};

#[test]
fn test_token_uri() {
    let contract = declare('ERC721NoGame');
    let calldata: Array<felt252> = array![
        'nogamenft', 'NGNFT', DEPLOYER().into(), DEPLOYER().into()
    ];
    let contract_address = contract.precalculate_address(@calldata);
    start_prank(CheatTarget::All, DEPLOYER());
    let contract_address = contract.deploy(@calldata).unwrap();
    let erc721 = IERC721NoGameDispatcher { contract_address };
    let erc721_metadata = IERC721NoGameDispatcher { contract_address };

    erc721.mint(ACCOUNT1(), 32);
    let token_uri = erc721_metadata.tokenURI(32);
    let mut i = 0;
    loop {
        if i == token_uri.len() {
            break;
        }
        (*token_uri.at(i));
        i += 1;
    }
}


fn base_uri_array() -> Array<felt252> {
    array![
        104,
        116,
        116,
        112,
        115,
        58,
        47,
        47,
        112,
        105,
        110,
        107,
        45,
        99,
        97,
        112,
        97,
        98,
        108,
        101,
        45,
        115,
        110,
        97,
        107,
        101,
        45,
        57,
        54,
        52,
        46,
        109,
        121,
        112,
        105,
        110,
        97,
        116,
        97,
        46,
        99,
        108,
        111,
        117,
        100,
        47,
        105,
        112,
        102,
        115,
        47,
        81,
        109,
        85,
        111,
        53,
        81,
        82,
        86,
        66,
        77,
        118,
        86,
        80,
        101,
        56,
        102,
        113,
        50,
        84,
        87,
        57,
        78,
        52,
        113,
        89,
        117,
        52,
        85,
        115,
        55,
        70,
        65,
        85,
        90,
        109,
        115,
        102,
        78,
        77,
        72,
        102,
        110,
        54,
        68,
        90,
        52,
        47,
    ]
}


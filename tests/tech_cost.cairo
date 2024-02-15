use nogame::libraries::research::Lab;
use nogame::libraries::types::ERC20s;

#[test]
fn multilevel_tech_cost_test() {
    let costs = Lab::base_tech_costs();

    let expected = ERC20s { steel: 0, quartz: 26213600, tritium: 13106800 };
    let cost = Lab::get_tech_cost(0, 15, costs.energy);
    assert(cost == expected, 'wrong assert 1');

    let expected = ERC20s { steel: 0, quartz: 406400, tritium: 203200 };
    let cost = Lab::get_tech_cost(2, 7, costs.energy);
    assert(cost == expected, 'wrong assert 2');

    let expected = ERC20s { steel: 0, quartz: 3251200, tritium: 1625600 };
    let cost = Lab::get_tech_cost(5, 7, costs.energy);
    assert(cost == expected, 'wrong assert 3');

    let expected = ERC20s { steel: 0, quartz: 107373772800, tritium: 53686886400 };
    let cost = Lab::get_tech_cost(9, 18, costs.energy);
    assert(cost == expected, 'wrong assert 4');

    let expected = ERC20s { steel: 0, quartz: 26840268800, tritium: 13420134400 };
    let cost = Lab::get_tech_cost(12, 13, costs.energy);
    assert(cost == expected, 'wrong assert 5');
}

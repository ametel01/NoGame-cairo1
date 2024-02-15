use nogame::libraries::compounds::{Compounds, Production};

#[test]
fn steel_production_test() {
    let production = Production::steel(0);
    assert(production == 10, 'wrong result');
    let production = Production::steel(1);
    assert(production == 33, 'wrong result');
    let production = Production::steel(5);
    assert(production == 241, 'wrong result');
    let production = Production::steel(10);
    assert(production == 778, 'wrong result');
    let production = Production::steel(20);
    assert(production == 4036, 'wrong result');
    let production = Production::steel(30);
    assert(production == 15704, 'wrong result');
    let production = Production::steel(60);
    assert(production == 548066, 'wrong result');
}
#[test]
fn quartz_production_test() {
    let production = Production::quartz(0);
    assert(production == 10, 'wrong result');
    let production = Production::quartz(1);
    assert(production == 22, 'wrong result');
    let production = Production::quartz(5);
    assert(production == 161, 'wrong result');
    let production = Production::quartz(10);
    assert(production == 518, 'wrong result');
    let production = Production::quartz(20);
    assert(production == 2690, 'wrong result');
    let production = Production::quartz(31);
    assert(production == 11900, 'wrong result');
    let production = Production::quartz(60);
    assert(production == 365377, 'wrong result');
}
#[test]
fn tritium_production_test() {
    let production = Production::tritium(0, 20, 1);
    assert(production == 0, 'wrong result #1');
    let production = Production::tritium(1, 20, 1);
    assert(production == 14, 'wrong result #2');
    let production = Production::tritium(5, 20, 1);
    assert(production == 102, 'wrong result #3');
    let production = Production::tritium(10, 20, 1);
    assert(production == 331, 'wrong result #4');
    let production = Production::tritium(20, 20, 1);
    assert(production == 1721, 'wrong result #5');
    let production = Production::tritium(31, 20, 1);
    assert(production == 7615, 'wrong result #6');
    let production = Production::tritium(60, 20, 1);
    assert(production == 233840, 'wrong result #7');
}
#[test]
fn energy_plant_production_test() {
    let production = Production::energy(0);
    assert(production == 0, 'wrong result');
    let production = Production::energy(1);
    assert(production == 22, 'wrong result');
    let production = Production::energy(5);
    assert(production == 161, 'wrong result');
    let production = Production::energy(10);
    assert(production == 518, 'wrong result');
    let production = Production::energy(20);
    assert(production == 2690, 'wrong result');
    let production = Production::energy(31);
    assert(production == 11900, 'wrong result');
    let production = Production::energy(60);
    assert(production == 365377, 'wrong result');
}
#[test]
fn production_scaler_test() {
    let scaled = Compounds::production_scaler(52, 100, 50);
    assert(scaled == 52, '');
    let scaled = Compounds::production_scaler(52, 80, 100);
    assert(scaled == 41, '');
    let scaled = Compounds::production_scaler(52, 60, 100);
    assert(scaled == 31, '');
    let scaled = Compounds::production_scaler(52, 20, 100);
    assert(scaled == 10, '');
}


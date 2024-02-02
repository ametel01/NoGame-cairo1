use nogame::libraries::types::{
    PlanetPosition, ColonyUpgradeType, ERC20s, ColonyBuildType, TechLevels, CompoundsLevels, Fleet,
    DefencesLevels
};

#[starknet::interface]
trait IColonyWrite<TState> {
    fn generate_colony(ref self: TState, planet_id: u32) -> (u8, PlanetPosition);
    fn collect_resources(
        ref self: TState, uni_speed: u128, planet_id: u32, colony_id: u8
    ) -> ERC20s;
    fn process_colony_compound_upgrade(
        ref self: TState, planet_id: u32, colony_id: u8, name: ColonyUpgradeType, quantity: u8
    );
    fn process_colony_unit_build(
        ref self: TState,
        planet_id: u32,
        colony_id: u8,
        techs: TechLevels,
        name: ColonyBuildType,
        quantity: u32,
        is_testnet: bool
    );
    fn get_colony_resources(
        self: @TState, uni_speed: u128, planet_id: u32, colony_id: u8
    ) -> ERC20s;
}

#[starknet::interface]
trait IColonyView<TState> {
    fn get_colonies_for_planet(self: @TState, planet_id: u32) -> Array<(u8, PlanetPosition)>;
    fn get_colony_coumpounds(self: @TState, planet_id: u32, colony_id: u8) -> CompoundsLevels;
    fn get_colony_ships(self: @TState, planet_id: u32, colony_id: u8) -> Fleet;
    fn get_colony_defences(self: @TState, planet_id: u32, colony_id: u8) -> DefencesLevels;
}

mod ResourceName {
    const STEEL: felt252 = 1;
    const QUARTZ: felt252 = 1;
    const TRITIUM: felt252 = 3;
}

#[starknet::component]
mod ColonyComponent {
    use starknet::{get_block_timestamp, get_caller_address};
    use nogame::libraries::types::{
        PlanetPosition, Names, ERC20s, CompoundsLevels, HOUR, ColonyUpgradeType, ColonyBuildType,
        TechLevels, ShipsLevels, DefencesLevels, Fleet
    };
    use nogame::colony::positions;
    use nogame::libraries::compounds::{Compounds, CompoundCost, Production, Consumption};
    use nogame::libraries::defences::{Defences};
    use nogame::libraries::dockyard::{Dockyard};
    use super::ResourceName;

    use snforge_std::PrintTrait;

    #[storage]
    struct Storage {
        colony_count: usize,
        planet_colonies_count: LegacyMap::<u32, u8>,
        colony_position: LegacyMap::<(u32, u8), PlanetPosition>,
        position_to_colony: LegacyMap::<PlanetPosition, (u32, u8)>,
        colony_resource_timer: LegacyMap<(u32, u8), u64>,
        colony_compounds: LegacyMap::<(u32, u8, felt252), u8>,
        colony_ships: LegacyMap::<(u32, u8, felt252), u32>,
        colony_defences: LegacyMap::<(u32, u8, felt252), u32>,
    }

    #[embeddable_as(ColonyWrite)]
    impl ColonyWriteImpl<
        TContractState, +HasComponent<TContractState>
    > of super::IColonyWrite<ComponentState<TContractState>> {
        fn generate_colony(
            ref self: ComponentState<TContractState>, planet_id: u32
        ) -> (u8, PlanetPosition) {
            let current_count = self.colony_count.read();
            let position = positions::get_colony_position(current_count);
            let colony_id = self.planet_colonies_count.read(planet_id) + 1;
            self.colony_position.write((planet_id, colony_id), position);
            self.position_to_colony.write(position, (planet_id, colony_id));
            self.planet_colonies_count.write(planet_id, colony_id);
            self.colony_resource_timer.write((planet_id, colony_id), get_block_timestamp());
            self.colony_count.write(current_count + 1);
            (colony_id, position)
        }

        fn collect_resources(
            ref self: ComponentState<TContractState>, uni_speed: u128, planet_id: u32, colony_id: u8
        ) -> ERC20s {
            assert!(
                !self.colony_position.read((planet_id, colony_id)).is_zero(),
                "NoGameColony: colony {} not present for planet {}",
                colony_id,
                planet_id
            );
            let production = self.calculate_colony_production(uni_speed, planet_id, colony_id);
            self.colony_resource_timer.write((planet_id, colony_id), get_block_timestamp());

            production
        }

        fn process_colony_compound_upgrade(
            ref self: ComponentState<TContractState>,
            planet_id: u32,
            colony_id: u8,
            name: ColonyUpgradeType,
            quantity: u8
        ) {
            assert!(
                !self.colony_position.read((planet_id, colony_id)).is_zero(),
                "NoGameColony: colony {} not present for planet {}",
                colony_id,
                planet_id
            );
            self.upgrade_component(planet_id, colony_id, name, quantity);
        }

        fn process_colony_unit_build(
            ref self: ComponentState<TContractState>,
            planet_id: u32,
            colony_id: u8,
            techs: TechLevels,
            name: ColonyBuildType,
            quantity: u32,
            is_testnet: bool
        ) {
            assert!(
                !self.colony_position.read((planet_id, colony_id)).is_zero(),
                "NoGameColony: colony {} not present for planet {}",
                colony_id,
                planet_id
            );
            self.build_component(planet_id, colony_id, techs, name, quantity, is_testnet);
        }

        fn get_colony_resources(
            self: @ComponentState<TContractState>, uni_speed: u128, planet_id: u32, colony_id: u8
        ) -> ERC20s {
            if self.colony_position.read((planet_id, colony_id)).is_zero() {
                return Zeroable::zero();
            }
            self.calculate_colony_production(uni_speed, planet_id, colony_id)
        }
    }

    #[embeddable_as(ColonyView)]
    impl ColonyViewImpl<
        TContractState, +HasComponent<TContractState>
    > of super::IColonyView<ComponentState<TContractState>> {
        fn get_colonies_for_planet(
            self: @ComponentState<TContractState>, planet_id: u32
        ) -> Array<(u8, PlanetPosition)> {
            let mut arr: Array<(u8, PlanetPosition)> = array![];
            let mut i = 1;
            loop {
                let colony_position = self.colony_position.read((planet_id, i));
                if colony_position.is_zero() {
                    break;
                }
                arr.append((i, colony_position));
                i += 1;
            };
            arr
        }

        fn get_colony_coumpounds(
            self: @ComponentState<TContractState>, planet_id: u32, colony_id: u8
        ) -> CompoundsLevels {
            CompoundsLevels {
                steel: self.colony_compounds.read((planet_id, colony_id, Names::STEEL)),
                quartz: self.colony_compounds.read((planet_id, colony_id, Names::QUARTZ)),
                tritium: self.colony_compounds.read((planet_id, colony_id, Names::TRITIUM)),
                energy: self.colony_compounds.read((planet_id, colony_id, Names::ENERGY_PLANT)),
                lab: 0,
                dockyard: self.colony_compounds.read((planet_id, colony_id, Names::DOCKYARD)),
            }
        }

        fn get_colony_ships(
            self: @ComponentState<TContractState>, planet_id: u32, colony_id: u8
        ) -> Fleet {
            Fleet {
                carrier: self.colony_ships.read((planet_id, colony_id, Names::CARRIER)),
                scraper: self.colony_ships.read((planet_id, colony_id, Names::SCRAPER)),
                sparrow: self.colony_ships.read((planet_id, colony_id, Names::SPARROW)),
                frigate: self.colony_ships.read((planet_id, colony_id, Names::FRIGATE)),
                armade: self.colony_ships.read((planet_id, colony_id, Names::ARMADE)),
            }
        }

        fn get_colony_defences(
            self: @ComponentState<TContractState>, planet_id: u32, colony_id: u8
        ) -> DefencesLevels {
            DefencesLevels {
                celestia: self.colony_defences.read((planet_id, colony_id, Names::CELESTIA)),
                blaster: self.colony_defences.read((planet_id, colony_id, Names::BLASTER)),
                beam: self.colony_defences.read((planet_id, colony_id, Names::BEAM)),
                astral: self.colony_defences.read((planet_id, colony_id, Names::ASTRAL)),
                plasma: self.colony_defences.read((planet_id, colony_id, Names::PLASMA)),
            }
        }
    }

    #[generate_trait]
    impl InternalImpl<
        TContractState, +HasComponent<TContractState>
    > of InternalTrait<TContractState> {
        fn reset_resource_timer(
            ref self: ComponentState<TContractState>, planet_id: u32, colony_id: u8
        ) {
            self.colony_resource_timer.write((planet_id, colony_id), get_block_timestamp());
        }

        fn update_defences_after_attack(
            ref self: ComponentState<TContractState>,
            planet_id: u32,
            colony_id: u8,
            d: DefencesLevels
        ) {
            self.colony_defences.write((planet_id, colony_id, Names::CELESTIA), d.celestia);
            self.colony_defences.write((planet_id, colony_id, Names::BLASTER), d.blaster);
            self.colony_defences.write((planet_id, colony_id, Names::BEAM), d.beam);
            self.colony_defences.write((planet_id, colony_id, Names::ASTRAL), d.astral);
            self.colony_defences.write((planet_id, colony_id, Names::PLASMA), d.plasma);
        }

        fn upgrade_component(
            ref self: ComponentState<TContractState>,
            planet_id: u32,
            colony_id: u8,
            component: ColonyUpgradeType,
            quantity: u8
        ) {
            match component {
                ColonyUpgradeType::SteelMine => {
                    let current_level = self
                        .colony_compounds
                        .read((planet_id, colony_id, Names::STEEL));
                    self
                        .colony_compounds
                        .write(
                            (planet_id, colony_id, Names::STEEL),
                            current_level + quantity.try_into().expect('u32 into u8 failed')
                        );
                },
                ColonyUpgradeType::QuartzMine => {
                    let current_level = self
                        .colony_compounds
                        .read((planet_id, colony_id, Names::QUARTZ));
                    self
                        .colony_compounds
                        .write(
                            (planet_id, colony_id, Names::QUARTZ),
                            current_level + quantity.try_into().expect('u32 into u8 failed')
                        );
                },
                ColonyUpgradeType::TritiumMine => {
                    let current_level = self
                        .colony_compounds
                        .read((planet_id, colony_id, Names::TRITIUM));
                    self
                        .colony_compounds
                        .write(
                            (planet_id, colony_id, Names::TRITIUM),
                            current_level + quantity.try_into().expect('u32 into u8 failed')
                        );
                },
                ColonyUpgradeType::EnergyPlant => {
                    let current_level = self
                        .colony_compounds
                        .read((planet_id, colony_id, Names::ENERGY_PLANT));
                    self
                        .colony_compounds
                        .write(
                            (planet_id, colony_id, Names::ENERGY_PLANT),
                            current_level + quantity.try_into().expect('u32 into u8 failed')
                        );
                },
                ColonyUpgradeType::Dockyard => {
                    let current_level = self
                        .colony_compounds
                        .read((planet_id, colony_id, Names::DOCKYARD));
                    self
                        .colony_compounds
                        .write(
                            (planet_id, colony_id, Names::DOCKYARD),
                            current_level + quantity.try_into().expect('u32 into u8 failed')
                        );
                },
            }
        }

        fn build_component(
            ref self: ComponentState<TContractState>,
            planet_id: u32,
            colony_id: u8,
            techs: TechLevels,
            component: ColonyBuildType,
            quantity: u32,
            is_tesnet: bool,
        ) {
            let dockyard_level = self
                .colony_compounds
                .read((planet_id, colony_id, Names::DOCKYARD));
            match component {
                ColonyBuildType::Carrier => {
                    Dockyard::carrier_requirements_check(dockyard_level, techs);
                    self
                        .colony_ships
                        .write(
                            (planet_id, colony_id, Names::CARRIER),
                            self.colony_ships.read((planet_id, colony_id, Names::CARRIER))
                                + quantity
                        );
                },
                ColonyBuildType::Scraper => {
                    Dockyard::scraper_requirements_check(dockyard_level, techs);
                    self
                        .colony_ships
                        .write(
                            (planet_id, colony_id, Names::SCRAPER),
                            self.colony_ships.read((planet_id, colony_id, Names::SCRAPER))
                                + quantity
                        );
                },
                ColonyBuildType::Sparrow => {
                    Dockyard::sparrow_requirements_check(dockyard_level, techs);
                    self
                        .colony_ships
                        .write(
                            (planet_id, colony_id, Names::SPARROW),
                            self.colony_ships.read((planet_id, colony_id, Names::SPARROW))
                                + quantity
                        );
                },
                ColonyBuildType::Frigate => {
                    Dockyard::frigate_requirements_check(dockyard_level, techs);
                    self
                        .colony_ships
                        .write(
                            (planet_id, colony_id, Names::FRIGATE),
                            self.colony_ships.read((planet_id, colony_id, Names::FRIGATE))
                                + quantity
                        );
                },
                ColonyBuildType::Armade => {
                    Dockyard::armade_requirements_check(dockyard_level, techs);
                    self
                        .colony_ships
                        .write(
                            (planet_id, colony_id, Names::ARMADE),
                            self.colony_ships.read((planet_id, colony_id, Names::ARMADE)) + quantity
                        );
                },
                ColonyBuildType::Celestia => {
                    Dockyard::celestia_requirements_check(dockyard_level, techs);
                    self
                        .colony_defences
                        .write(
                            (planet_id, colony_id, Names::CELESTIA),
                            self.colony_defences.read((planet_id, colony_id, Names::CELESTIA))
                                + quantity
                        );
                },
                ColonyBuildType::Blaster => {
                    Defences::blaster_requirements_check(dockyard_level, techs);
                    self
                        .colony_defences
                        .write(
                            (planet_id, colony_id, Names::BLASTER),
                            self.colony_defences.read((planet_id, colony_id, Names::BLASTER))
                                + quantity
                        );
                },
                ColonyBuildType::Beam => {
                    Defences::beam_requirements_check(dockyard_level, techs);
                    self
                        .colony_defences
                        .write(
                            (planet_id, colony_id, Names::BEAM),
                            self.colony_defences.read((planet_id, colony_id, Names::BEAM))
                                + quantity
                        );
                },
                ColonyBuildType::Astral => {
                    Defences::astral_launcher_requirements_check(dockyard_level, techs);
                    self
                        .colony_defences
                        .write(
                            (planet_id, colony_id, Names::ASTRAL),
                            self.colony_defences.read((planet_id, colony_id, Names::ASTRAL))
                                + quantity
                        );
                },
                ColonyBuildType::Plasma => {
                    Defences::plasma_beam_requirements_check(dockyard_level, techs);
                    self
                        .colony_defences
                        .write(
                            (planet_id, colony_id, Names::PLASMA),
                            self.colony_defences.read((planet_id, colony_id, Names::PLASMA))
                                + quantity
                        );
                },
            }
        }

        fn get_planet_colony_count(self: @ComponentState<TContractState>, planet_id: u32) -> u8 {
            self.planet_colonies_count.read(planet_id)
        }


        fn get_coumpounds_levels(
            self: @ComponentState<TContractState>, planet_id: u32, colony_id: u8
        ) -> CompoundsLevels {
            CompoundsLevels {
                steel: self.colony_compounds.read((planet_id, colony_id, Names::STEEL)),
                quartz: self.colony_compounds.read((planet_id, colony_id, Names::QUARTZ)),
                tritium: self.colony_compounds.read((planet_id, colony_id, Names::TRITIUM)),
                energy: self.colony_compounds.read((planet_id, colony_id, Names::ENERGY_PLANT)),
                lab: 0,
                dockyard: self.colony_compounds.read((planet_id, colony_id, Names::ENERGY_PLANT)),
            }
        }

        fn calculate_colony_production(
            self: @ComponentState<TContractState>, uni_speed: u128, planet_id: u32, colony_id: u8
        ) -> ERC20s {
            let time_now = get_block_timestamp();
            let last_collection_time = self.colony_resource_timer.read((planet_id, colony_id));
            let time_elapsed = time_now - last_collection_time;
            let mines_levels = self.get_coumpounds_levels(planet_id, colony_id);
            let position = self.colony_position.read((planet_id, colony_id));
            let temp = self.calculate_avg_temperature(position.orbit);
            let steel_available = Production::steel(mines_levels.steel)
                * uni_speed
                * time_elapsed.into()
                / HOUR.into();

            let quartz_available = Production::quartz(mines_levels.quartz)
                * uni_speed
                * time_elapsed.into()
                / HOUR.into();

            let tritium_available = Production::tritium(mines_levels.tritium, temp, uni_speed)
                * time_elapsed.into()
                / HOUR.into();

            let colony_position = self.colony_position.read((planet_id, colony_id));
            let celestia_production = self.position_to_celestia_production(colony_position.orbit);
            let celestia_production: u128 = self
                .get_colony_defences(planet_id, colony_id)
                .celestia
                .into()
                * celestia_production;
            let energy_available = Production::energy(mines_levels.energy);
            let energy_required = Consumption::base(mines_levels.steel)
                + Consumption::base(mines_levels.quartz)
                + Consumption::base(mines_levels.tritium);
            let total_production = energy_available + celestia_production;

            if total_production < energy_required {
                let _steel = Compounds::production_scaler(
                    steel_available, total_production, energy_required
                );
                let _quartz = Compounds::production_scaler(
                    quartz_available, total_production, energy_required
                );
                let _tritium = Compounds::production_scaler(
                    tritium_available, total_production, energy_required
                );

                return ERC20s { steel: _steel, quartz: _quartz, tritium: _tritium, };
            }

            ERC20s { steel: steel_available, quartz: quartz_available, tritium: tritium_available, }
        }

        fn calculate_avg_temperature(self: @ComponentState<TContractState>, orbit: u8) -> u32 {
            if orbit == 1 {
                return 230;
            }
            if orbit == 2 {
                return 170;
            }
            if orbit == 3 {
                return 120;
            }
            if orbit == 4 {
                return 70;
            }
            if orbit == 5 {
                return 60;
            }
            if orbit == 6 {
                return 50;
            }
            if orbit == 7 {
                return 40;
            }
            if orbit == 8 {
                return 40;
            }
            if orbit == 9 {
                return 20;
            } else {
                return 10;
            }
        }

        fn fleet_arrives(
            ref self: ComponentState<TContractState>, planet_id: u32, colony_id: u8, fleet: Fleet
        ) {
            let fleet_levels = self.get_colony_ships(planet_id, colony_id);
            if fleet.carrier > 0 {
                self
                    .colony_ships
                    .write(
                        (planet_id, colony_id, Names::CARRIER), fleet_levels.carrier + fleet.carrier
                    );
            }
            if fleet.scraper > 0 {
                self
                    .colony_ships
                    .write(
                        (planet_id, colony_id, Names::SCRAPER), fleet_levels.scraper + fleet.scraper
                    );
            }
            if fleet.sparrow > 0 {
                self
                    .colony_ships
                    .write(
                        (planet_id, colony_id, Names::SPARROW), fleet_levels.sparrow + fleet.sparrow
                    );
            }
            if fleet.frigate > 0 {
                self
                    .colony_ships
                    .write(
                        (planet_id, colony_id, Names::FRIGATE), fleet_levels.frigate + fleet.frigate
                    );
            }
            if fleet.armade > 0 {
                self
                    .colony_ships
                    .write(
                        (planet_id, colony_id, Names::ARMADE), fleet_levels.armade + fleet.armade
                    );
            }
        }

        fn fleet_leaves(
            ref self: ComponentState<TContractState>, planet_id: u32, colony_id: u8, fleet: Fleet
        ) {
            let fleet_levels = self.get_colony_ships(planet_id, colony_id);
            if fleet.carrier > 0 {
                self
                    .colony_ships
                    .write(
                        (planet_id, colony_id, Names::CARRIER), fleet_levels.carrier - fleet.carrier
                    );
            }
            if fleet.scraper > 0 {
                self
                    .colony_ships
                    .write(
                        (planet_id, colony_id, Names::SCRAPER), fleet_levels.scraper - fleet.scraper
                    );
            }
            if fleet.sparrow > 0 {
                self
                    .colony_ships
                    .write(
                        (planet_id, colony_id, Names::SPARROW), fleet_levels.sparrow - fleet.sparrow
                    );
            }
            if fleet.frigate > 0 {
                self
                    .colony_ships
                    .write(
                        (planet_id, colony_id, Names::FRIGATE), fleet_levels.frigate - fleet.frigate
                    );
            }
            if fleet.armade > 0 {
                self
                    .colony_ships
                    .write(
                        (planet_id, colony_id, Names::ARMADE), fleet_levels.armade - fleet.armade
                    );
            }
        }

        fn position_to_celestia_production(
            self: @ComponentState<TContractState>, orbit: u8
        ) -> u128 {
            if orbit == 1 {
                return 48;
            }
            if orbit == 2 {
                return 41;
            }
            if orbit == 3 {
                return 36;
            }
            if orbit == 4 {
                return 32;
            }
            if orbit == 5 {
                return 27;
            }
            if orbit == 6 {
                return 24;
            }
            if orbit == 7 {
                return 21;
            }
            if orbit == 8 {
                return 17;
            }
            if orbit == 9 {
                return 14;
            } else {
                return 11;
            }
        }
    }
}

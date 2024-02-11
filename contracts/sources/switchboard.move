module coin_x_oracle::switchboard {
  // === Imports ===
  use std::type_name;
  
  use sui::dynamic_field as df;

  use suitears::owner::OwnerCap;
  use suitears::oracle::{Self, Oracle, Request};  

  use switchboard::math;
  use switchboard::aggregator::{Self, Aggregator};

  // === Errors ===

  const ENegativeValueIsNotValid: u64 = 0;
  const EInvalidAggregator: u64 = 1;

  // === Structs ===

  struct AggregatorKey has copy, drop, store {}

  struct SwitchboardFeed has drop {}

  // === Public-Mutative Functions ===

  /*
  * @notice Adds the Switchboard feed to the `oracle`.  
  *
  * @param self The `Oracle` that will support Switchboard.    
  * @param cap The `suitears::owner::OwnerCap` of `self`.   
  * @param aggregator `switchboard::aggregator::Aggregator` that the `self` will use to report the price.  
  */
  public fun new<Witness: drop>(oracle: &mut Oracle<Witness>, cap: &OwnerCap<Witness>, aggregator: &Aggregator) {
    oracle::add(oracle, cap, type_name::get<SwitchboardFeed>());
    let uid = oracle::uid_mut(oracle, cap);
    df::add(uid, AggregatorKey {}, aggregator::aggregator_address(aggregator));
  }

  public fun report<Witness: drop>(oracle: &Oracle<Witness>, request: &mut Request, aggregator: &Aggregator) {
    let whitelisted_address = *df::borrow<AggregatorKey, address>(oracle::uid(oracle), AggregatorKey {});
    assert!(aggregator::aggregator_address(aggregator) == whitelisted_address, EInvalidAggregator);

    let (latest_result, latest_timestamp) = aggregator::latest_value(aggregator);

    let (value, scaling_factor, neg) = math::unpack(latest_result);

    assert!(!neg, ENegativeValueIsNotValid);

    oracle::report(request, SwitchboardFeed {}, latest_timestamp, value, scaling_factor);
  }
}
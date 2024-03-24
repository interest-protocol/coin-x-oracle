module coin_x_oracle::switchboard_oracle {
  // // === Imports ===
  // use std::type_name;
  
  // use sui::dynamic_field as df;

  // use suitears::owner::OwnerCap;
  // use suitears::oracle::{Self, Oracle, Request};  

  // use switchboard_std::math::unpack;
  // use switchboard_std::aggregator::{Self, Aggregator};

  // // === Errors ===

  // const ENegativeValueIsNotValid: u64 = 0;
  // const EInvalidAggregator: u64 = 1;

  // // === Structs ===

  // struct AggregatorKey has copy, drop, store {}

  // struct SwitchboardFeed has drop {}

  // // === Public-Mutative Functions ===

  // /*
  // * @notice Adds a `SwitchboardFeed` report to a `suitears::oracle::Request`.  
  // *
  // * @param self A `suiterars::oracle::Oracle` with this module's witness.    
  // * @param request A hot potato issued from the `self` to create a `suiterars::oracle::Price`.  
  // * @param aggregator `switchboard::aggregator::Aggregator` that the `self` will use to fetch the price.  
  // *
  // * aborts-if:    
  // * - The `aggregator` is not whitelisted.   
  // * - The `aggregator` price is negative or zero.  
  // */
  // public fun report<Witness: drop>(oracle: &Oracle<Witness>, request: &mut Request, aggregator: &Aggregator) {
  //   let whitelisted_address = *df::borrow<AggregatorKey, address>(oracle::uid(oracle), AggregatorKey {});
  //   assert!(aggregator::aggregator_address(aggregator) == whitelisted_address, EInvalidAggregator);

  //   let (latest_result, latest_timestamp) = aggregator::latest_value(aggregator);

  //   let (value, scaling_factor, neg) = unpack(latest_result);

  //   assert!(!neg, ENegativeValueIsNotValid);

  //   oracle::report(request, SwitchboardFeed {}, latest_timestamp, value, scaling_factor);
  // }

  // // === Admin Functions ===  

  // /*
  // * @notice Adds the `SwitchboardFeed` to an `oracle`.  
  // *
  // * @param self The `suiterars::oracle::Oracle` that will require a Switchboard report.    
  // * @param cap The `suitears::owner::OwnerCap` of `self`.   
  // * @param aggregator `switchboard::aggregator::Aggregator` that the `self` will use to report the price.  
  // *
  // * aborts-if:   
  // * - The `self` has the this module's witness already.
  // */
  // public fun add<Witness: drop>(oracle: &mut Oracle<Witness>, cap: &OwnerCap<Witness>, aggregator: &Aggregator) {
  //   oracle::add(oracle, cap, type_name::get<SwitchboardFeed>());
  //   let uid = oracle::uid_mut(oracle, cap);
  //   df::add(uid, AggregatorKey {}, aggregator::aggregator_address(aggregator));
  // }  
}
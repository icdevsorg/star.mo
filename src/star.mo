import Prim "mo:⛔";
import P "mo:base/Prelude";
import Order "mo:base/Order";
import Result "mo:base/Result";

module {

  /// `Star<Ok, Err>` is the type used for returning and propagating async* behavior and errors. It
  /// is a type with the variants, `#trapable(Ok)`, representing success and containing
  /// a value produced without an awaited call, `#commited(Ok)`, representing success and containing
  /// a value produced with an awaited call,and `#err(Err)`, representing error and containing an error value.
  ///
  /// The simplest way of working with `Star`s is to pattern match on them:
  ///
  /// For example, given a function `createUser(user : User) : Star<Id, String>`
  /// where `String` is an error message we could use it like so:
  /// ```motoko no-repl
  /// switch(createUser(myUser)) {
  ///   case (#awaited(id)) { Debug.print("Created new user with id and state commited: " # id) };
  ///   case (#trapable(id)) { Debug.print("Created new user with id and state has not been commited: " # id) };
  ///   case (#err(msg)) { Debug.print("Failed to create user with the error: " # msg) };
  /// }
  /// ```
  public type Star<Ok, Err> = {
    #trapable : Ok;
    #awaited : Ok;
    #err : {
      #trapable: Err;
      #awaited: Err;
    };
  };

  // Compares two Star's for equality.
  public func equal<Ok, Err>(
    eqOk : (Ok, Ok) -> Bool,
    eqErr : (Err, Err) -> Bool,
    r1 : Star<Ok, Err>,
    r2 : Star<Ok, Err>
  ) : Bool {
    switch (r1, r2) {
      case (#trapable(ok1), #trapable(ok2)) {
        eqOk(ok1, ok2)
      };
      case (#awaited(ok1), #awaited(ok2)) {
        eqOk(ok1, ok2)
      };
      case (#err(#trapable(err1)), #err(#trapable(err2))) {
        eqErr(err1, err2)
      };
      case (#err(#awaited(err1)), #err(#awaited(err2))) {
        eqErr(err1, err2)
      };
      case _ { false }
    }
  };

  // Compares two Stars. `#ok` is larger than `#err`. This ordering is
  // arbitrary, but it lets you for example use Results as keys in ordered maps.
  public func compare<Ok, Err>(
    compareOk : (Ok, Ok) -> Order.Order,
    compareErr : (Err, Err) -> Order.Order,
    r1 : Star<Ok, Err>,
    r2 : Star<Ok, Err>
  ) : Order.Order {
    switch (r1, r2) {
      case (#trapable(ok1), #trapable(ok2)) {
        compareOk(ok1, ok2)
      };
      case (#awaited(ok1), #awaited(ok2)) {
        compareOk(ok1, ok2)
      };
      case (#err(err1), #err(err2)) {
        switch(err1, err2){
          case(#trapable(err1),#trapable(err2)){
            compareErr(err1, err2);
          };
          case(#awaited(err1),#trapable(err2)){
            compareErr(err1, err2);
          };
          case(#trapable(err1),#awaited(err2)){
            compareErr(err1, err2);
          };
          case(#awaited(err1),#awaited(err2)){
            compareErr(err1, err2);
          };
        };
        
      };
      case (#awaited(ok1), #trapable(ok2)) {
        compareOk(ok1, ok2)
      };
      case (#trapable(ok1), #awaited(ok2)) {
        compareOk(ok1, ok2)
      };
      case (#trapable(_), #err(_)) {
        #greater
      };
      case (#awaited(_), #err(_)) {
        #greater
      };
      case (#err(_), _) { #less }
    }
  };

  /// Allows sequencing of `Star` values and functions that return
  /// `Stars`'s themselves.
  /// ```motoko
  /// import Star "mo:base/Star";
  /// type Star<T,E> = Result.Result<T, E>;
  /// func largerThan10(x : Nat) : async* Star<Nat, Text> =
  ///   if (x > 10) { #trapable(x) } else {#err("Not larger than 10.") };
  ///
  /// func smallerThan20(x : Nat) : async* Star<Nat, Text> =
  ///   if (x < 20) { #awaited(await service(x)) } else { #err("Not smaller than 20.") };
  ///
  /// func between10And20(x : Nat) : Star<Nat, Text> =
  ///   Result.chain(largerThan10(x), smallerThan20);
  ///
  /// assert(between10And20(15) == #awaited(15));
  /// assert(between10And20(9) == #err("Not larger than 10."));
  /// assert(between10And20(21) == #err("Not smaller than 20."));
  /// ```
  public func chain<S1, S2, Error>(
    x : Star<S1, Error>,
    y : S1 -> Star<S2, Error>
  ) : Star<S2, Error> {
    switch x {
      case (#err(e)) { #err(e) };
      case (#awaited(r)) { 
        switch(y(r)){
          case(#awaited(r)){
            #awaited(r);
          };
          case(#trapable(r)){
            //since initial call was awaited, all following should inherit awaited status
            #awaited(r);
          };
          case(#err(r)){
            #err(r);
          };
        };
      };
      case (#trapable(r)) { y(r) }
    };
  };

  /// Flattens a nested Star.
  ///
  /// ```motoko
  /// import Star "mo:base/Result";
  /// assert(Star.flatten<Nat, Text>(#trapable(#trapable(10))) == #trapable(10));
  /// assert(Star.flatten<Nat, Text>(#err(#awaited("Wrong"))) == #err(#awaited("Wrong")));
  /// assert(Star.flatten<Nat, Text>(#err(#trapable("Wrong"))) == #err(#trapable("Wrong")));
  /// assert(Star.flatten<Nat, Text>(#trapable(#err(#awaited("Wrong")))) == #err(#awaited("Wrong")));
  /// assert(Star.flatten<Nat, Text>(#trapable(#err(#trapable("Wrong")))) == #err(#trapable("Wrong")));
  /// assert(Star.flatten<Nat, Text>(#awaited(#err(#awaited("Wrong")))) == #err(#awaited("Wrong")));
  /// assert(Star.flatten<Nat, Text>(#awaited(#err(#trapable("Wrong")))) == #err(#awaited("Wrong")));
  /// ```
  public func flatten<Ok, Error>(
    result : Star<Star<Ok, Error>, Error>
  ) : Star<Ok, Error> {
    switch result {
      case (#awaited(ok)) { 
        switch(ok){
          case (#awaited(ok)){
            #awaited(ok);
          };
          case (#trapable(ok)){
            #awaited(ok);
          };
          case(#err(e)){
            switch(e){
              case(#trapable(e)){
                #err(#awaited(e));
              };
              case(#awaited(e)){
                #err(#awaited(e));
              };
            }
          };
        } 
      };
      case (#trapable(ok)) { ok };
      case (#err(err)) { #err(err)};
    };
  };

  /// Maps the `Ok` type/value, leaving any `Error` type/value unchanged.
  public func mapOk<Ok1, Ok2, Error>(
    x : Star<Ok1, Error>,
    f : Ok1 -> Ok2
  ) : Star<Ok2, Error> {
    switch x {
      case (#err(e)) { #err(e) };
      case (#awaited(r)) { #awaited(f(r))};
      case (#trapable(r)) { #trapable(f(r))};
    };
  };

  /// Maps the `Err` type/value, leaving any `Ok` type/value unchanged.
  public func mapErr<Ok, Error1, Error2>(
    x : Star<Ok, Error1>,
    f : Error1 -> Error2
  ) : Star<Ok, Error2> {
    switch x {
      case (#err(e)) { 
        switch(e){
          case(#trapable(e)){
            #err(#trapable(f(e))) 
          };
          case(#awaited(e)){
            #err(#awaited(f(e)))
          }
        };
      };
      case (#awaited(r)) { #awaited(r) };
      case (#trapable(r)) { #trapable(r) }
    }
  };

  /// Create a star from an option, including an error value to handle the `null` case.
  /// ```motoko
  /// import Star "mo:base/Star";
  /// assert(Star.fromOption(?42, "err") == #trapable(42));
  /// assert(Star.fromOption(null, "err") == #err(#trapable("err")));
  /// ```
  public func fromOption<R, E>(x : ?R, err : E) : Star<R, E> {
    switch x {
      case (?x) { #trapable(x) };
      case null { #err(#trapable(err)) }
    }
  };

  /// Create an option from a star, turning all #err into `null`.
  /// ```motoko
  /// import Star "mo:base/Star";
  /// assert(Star.toOption(#trapable(42)) == ?42);
  /// assert(Star.toOption(#awaited(42)) == ?42);
  /// assert(Star.toOption(#err(#trapable("err"))) == null);
  /// assert(Star.toOption(#err(#awaited("err"))) == null);
  /// ```
  public func toOption<R, E>(r : Star<R, E>) : ?R {
    switch r {
      case (#trapable(x)) { ?x };
      case (#awaited(x)) { ?x };
      case (#err(_)) { null }
    }
  };

  /// Create a result from a star, turning all #awaited and #trapable into #ok and all #err() into #err.
  /// ```motoko
  /// import Star "mo:base/Star";
  /// assert(Star.toResult(#trapable(42)) == #ok(42));
  /// assert(Star.toResult(#awaited(42)) == #ok(42));
  /// assert(Star.toResult(#err(#trapable("err"))) == #err("err"));
  /// assert(Star.toResult(#err(#awaited("err"))) == #err("err"));
  /// ```
  public func toResult<R, E>(r : Star<R, E>) : Result.Result<R, E> {
    switch r {
      case (#trapable(x)) { #ok(x) };
      case (#awaited(x)) { #ok(x) };
      case (#err(e)) { 
        switch(e){
          case(#trapable(e)){
            #err(e);
          };
          case(#awaited(e)){
            #err(e);
          };
        };
       };
    };
  };

  /// Create a star from a result
  /// ```motoko
  /// import Star "mo:base/Star";
  /// assert(Star.fromResult(#ok(42), true) == #awaited(42));
  /// assert(Star.fromResult(#ok(42), false) == #trapable(42));
  /// assert(Star.fromOption(#err("err"), false) == #err(#trapable("err")));
  /// assert(Star.fromOption(#err("err"), true) == #err(#awaited("err")));
  /// ```
  public func fromResult<R, E>(x : Result.Result<R,E>, awaited : Bool) : Star<R, E> {
    switch (x, awaited) {
      case (#ok(x), false) { #trapable(x) };
      case (#ok(x), true) { #awaited(x) };
      case (#err(err), true) { #err(#awaited(err)) };
      case (#err(err), false) { #err(#trapable(err)) };
    }
  };

  /// Applies a function to a successful value, but discards the result. Use
  /// `iterate` if you're only interested in the side effect `f` produces.
  ///
  /// ```motoko
  /// import Star "mo:base/Star";
  /// var counter : Nat = 0;
  /// Star.iterate<Nat, Text>(#awaited(5), func (x : Nat) { counter += x });
  /// assert(counter == 5);
  /// Star.iterate<Nat, Text>(#err(#trapable("Wrong")), func (x : Nat) { counter += x });
  /// assert(counter == 5);
  /// ```
  public func iterate<Ok, Err>(res : Star<Ok, Err>, f : Ok -> ()) {
    switch res {
      case (#awaited(ok)) { f(ok) };
      case (#trapable(ok)) { f(ok) };
      case _ {}
    }
  };

  // Whether this Star is an `#ok`
  public func isOk(r : Star<Any, Any>) : Bool {
    switch r {
      case (#awaited(_)) { true };
      case (#trapable(_)) { true };
      case (#err(_)) { false }
    }
  };

  // Whether this Star is awaited and has had a state commitment
  public func isAwaited(r : Star<Any, Any>) : Bool {
    switch r {
      case (#awaited(_)) { true };
      case (#trapable(_)) { false };
      case (#err(e)) {
        switch(e){
          case(#awaited(e)) true;
          case(#trapable(e)) false;
        };
       };
    };
  };

  // Whether this Star is trapable
  public func isTrapable(r : Star<Any, Any>) : Bool {
    switch r {
      case (#awaited(_)) { false };
      case (#trapable(_)) { true };
      case (#err(e)) {
        switch(e){
          case(#awaited(e)) false;
          case(#trapable(e)) true;
        };
       };
    };
  };

  // Whether this Result is an `#err`
  public func isErr(r : Star<Any, Any>) : Bool {
    switch r {
      
      case (#err(_)) { true };
      case (_) false;
    }
  };

  /// Asserts that its argument is an `#awaited` or `#trapable` result, traps otherwise.
  public func assertOk(r : Star<Any, Any>) {
    switch (r) {
      case (#err(_)) { assert false };
      case (_) {}
    }
  };

  /// Asserts that its argument is an `#err` result, traps otherwise.
  public func assertErr(r : Star<Any, Any>) {
    switch (r) {
      case (#err(_)) {};
      case (#awaited(_)) assert false;
      case (#trapable(_)) assert false
    }
  };

  /// Asserts that its argument is an `#trapable` result, traps otherwise.
  public func assertTrapable(r : Star<Any, Any>) {
    switch (r) {
      case (#err(_)) assert false;
      case (#awaited(_)) assert false;
      case (#trapable(_)) {};
    }
  };

  /// Asserts that its argument is an `#err` result, traps otherwise.
  public func assertAwaited(r : Star<Any, Any>) {
    switch (r) {
      case (#err(_)) assert false;
      case (#awaited(_)) {};
      case (#trapable(_)) assert false;
    }
  };

}

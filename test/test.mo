
import Star "../src/star";
import Int "mo:base/Int";
import Array "mo:base/Array";
import List "mo:base/List";

import Suite "mo:matchers/Suite";
import M "mo:matchers/Matchers";
import T "mo:matchers/Testable";

shared (deployer) actor class Nft_Canister() = this {

  public shared func test() : async Bool{

    func makeNatural(x : Int) : Star.Star<Nat, Text> = if (x >= 0) {
      #trappable(Int.abs(x))
    } else { #err(#trappable(Int.toText(x) # " is not a natural number.")) };

    func largerThan10(x : Nat) : Star.Star<Nat, Text> = if (x > 10) { #trappable(x) } else {
      #err(#trappable(Int.toText(x) # " is not larger than 10."))
    };

    func largerThan20async(x : Nat) : async* Star.Star<Nat, Text> {
      if (x > 20) { #awaited(x) } else {
        #err(#awaited(Int.toText(x) # " is not larger than 10."))
      };
    };

    let flatten = Suite.suite(
      "flatten",
      [
        Suite.test(
          "ok -> ok",
          Star.toResult(Star.flatten<Nat, Text>(#awaited(#trappable(10)))),
          M.equals(T.result<Nat, Text>(T.natTestable, T.textTestable, #ok(10)))
        ),
        Suite.test(
          "err",
          Star.toResult(Star.flatten<Nat, Text>(#err(#trappable("wrong")))),
          M.equals(T.result<Nat, Text>(T.natTestable, T.textTestable, #err("wrong")))
        ),
        Suite.test(
          "ok -> err",
          Star.toResult(Star.flatten<Nat, Text>(#awaited(#err(#awaited("wrong"))))),
          M.equals(T.result<Nat, Text>(T.natTestable, T.textTestable, #err("wrong")))
        )
      ]
    );

    let iterate = Suite.suite(
      "iterate",
      do {
        var tests : [Suite.Suite] = [];
        var counter : Nat = 0;
        Star.iterate(makeNatural(5), func(x : Nat) { counter += x });
        tests := Array.append(tests, [Suite.test("ok", counter, M.equals(T.nat(5)))]);
        Star.iterate(makeNatural(-10), func(x : Nat) { counter += x });
        tests := Array.append(tests, [Suite.test("err", counter, M.equals(T.nat(5)))]);
        tests
      }
    );

    let suite = Suite.suite(
      "Result",
      [
      
        flatten,
        iterate
      ]
    );

    Suite.run(suite);
    return true;
  };
};
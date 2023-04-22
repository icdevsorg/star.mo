# Star Motoko Library - star.mo

A Motoko library for handling asynchronous and trappable behavior with the async* functions.

## Overview

`Star` is a custom type with three variants: `#trappable`, `#awaited`, and `#err`. These represent different states of success or failure. `#trappable` and `#awaited` represent success, while `#err` represents error. The difference between `#trappable` and `#awaited` is that `#awaited` is produced with an awaited call, while `#trappable` is produced without one.

This distinction is important because a value returned from an async* function carries no state information about whether the called function made a state commitment or not.  You will not know if the logic before your call has been committed to the state tree or not.

The suggested pattern is to never use async* without returning a Star and handling the four possible states:

- an await occured and you have a return value  #awaited(X)
- an await did not occur and you have a return value #trappable(X)
- an error occured but state was committed. #err(#awaited(E))
- an error occured but state was not committed. #err(#trappable(E))

## Usage

To use this library in your project, you will need to import it first.

mops install star

```motoko
import Star "mo:star/star";
```

Requires at least moc 0.8.3.

Then, you can use the provided functions to work with Star types:

```
equal
compare
flatten
mapOk
mapErr
fromOption
toOption
toResult
fromResult
iterate
isOk
isAwaited
isTrappable
isErr
assertOk
assertErr
assertTrappable
assertAwaited
```

Example
Here's an example of using a Star type with a function createUser(user : User) : Star<Id, String>:

```
switch(await* createUser(myUser)) {
  case (#awaited(id)) { Debug.print("Created new user with id and state committed: " # id) };
  case (#trappable(id)) { Debug.print("Created new user with id and state has not been committed: " # id) };
  case (#err(#awaited(msg))) { Debug.print("Failed to create user with the error but state was committed: " # msg) };
  case (#err(#trappable(msg))) { Debug.print("Failed to create user with the error but state was not committed: " # msg) };
}
```

## License

This library is provided under the MIT License.

## Contributing
Please feel free to open issues or submit pull requests for any bug fixes or improvements.
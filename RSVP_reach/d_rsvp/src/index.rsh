'reach 0.1';

const [isHand, APPROVE, PAPER, DECLINE] = makeEnum(3);
const [isOutcome, B_WINS, DRAW, A_WINS] = makeEnum(3);

const winner = (handAlice, handBob) =>
  ((handAlice + (4 - handBob)) % 3);

assert(winner(APPROVE, PAPER) == B_WINS);
assert(winner(PAPER, APPROVE) == A_WINS);
assert(winner(APPROVE, APPROVE) == DRAW);

forall(UInt, handAlice =>
  forall(UInt, handBob =>
    assert(isOutcome(winner(handAlice, handBob)))));

forall(UInt, (hand) =>
  assert(winner(hand, hand) == DRAW));

const Player = {
  ...hasRandom,
  seeOutcome: Fun([UInt], Null),
  informTimeout: Fun([], Null),
};

export const main = Reach.App(() => {
  const Alice = Participant('Alice', {
    ...Player,
    eventFee: UInt, // atomic units of currency
    deadline: UInt, // time delta (blocks/rounds)
    approveInvitee: Fun([], UInt),
  });
  const Bob = Participant('Bob', {
    ...Player,
    acceptEventFee: Fun([UInt], Null),
  });
  init();

  const informTimeout = () => {
    each([Alice, Bob], () => {
      interact.informTimeout();
    });
  };

  Alice.only(() => {
    const eventFee = declassify(interact.eventFee);
    const deadline = declassify(interact.deadline);
  });
  Alice.publish(eventFee, deadline)
    .pay(eventFee);
  commit();

  Bob.only(() => {
    interact.acceptEventFee(eventFee);
  });
  Bob.pay(eventFee)
    .timeout(relativeTime(deadline), () => closeTo(Alice, informTimeout));
  transfer(eventFee).to(Alice);

  var outcome = DRAW;
  invariant(balance() == eventFee && isOutcome(outcome));
  while (outcome == DRAW) {
    commit();

    Alice.only(() => {
      const _handAlice = interact.approveInvitee();
      const approvalStatus = declassify(_handAlice);
    });
    Alice.publish(approvalStatus)
      .timeout(relativeTime(deadline), () => closeTo(Bob, informTimeout));

    if (approvalStatus === B_WINS) {
      outcome = B_WINS;
      continue;
    }

    if (approvalStatus === A_WINS) {
      outcome = A_WINS;
      continue;
    }

    continue;
  }

  assert(outcome == A_WINS || outcome == B_WINS);
  transfer(eventFee).to(outcome == A_WINS ? Alice : Bob);
  commit();

  each([Alice, Bob], () => {
    interact.seeOutcome(outcome);
  });
});
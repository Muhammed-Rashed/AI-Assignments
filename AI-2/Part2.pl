% calculate adjacent coordinates
adjacent((R, C), (NR, C)) :- NR is R + 1. % Down
adjacent((R, C), (NR, C)) :- NR is R - 1. % Up
adjacent((R, C), (R, NC)) :- NC is C + 1. % Right
adjacent((R, C), (R, NC)) :- NC is C - 1. % Left

% check if (R, C) is actually inside the grid
in_bounds((R, C), Grid) :-
    length(Grid, MaxR),
    nth1(1, Grid, FirstRow),
    length(FirstRow, MaxC),
    R >= 1, R =< MaxR,
    C >= 1, C =< MaxC.

% content of the grid at (R, C)
get_cell(Grid, (R, C), Content) :-
    nth1(R, Grid, Row),
    nth1(C, Row, Content).

% generate a valid next state with battery constraint
move(state((R, C), Grid, Path, Battery, SCount),state((NR, NC), Grid, [(NR, NC)|Path], NewBattery, NewSCount)) :-
    adjacent((R, C), (NR, NC)),
    in_bounds((NR, NC), Grid),
    \+ member((NR, NC), Path),
    get_cell(Grid, (NR, NC), Content),
    Content \= d, % can't go into debris
    Content \= f, % can't go into fire
    NewBattery is Battery - 10,
    NewBattery > 0,
    (Content = s -> NewSCount is SCount + 1 ; NewSCount is SCount). % increment survivor count if we find one

% find the starting position of the robot
find_robot(Grid, (R, C)) :-
    nth1(R, Grid, Row),
    nth1(C, Row, r).

% generate all valid next states (children)
expand(State, Children) :-
    % "Children" means all possible states we can reach in ONE move
    % from the current state.
    % findall tries every possible move/2 and collects all valid results.
    findall(NextState, move(State, NextState), Children).

% check if position already visited (closed list)
visited(state(Pos, _, _, _), Closed) :-
    member(Pos, Closed).

% --- HEURISTIC ---
calculateH(state(_, Grid, Path, _, _), SurvivorScore) :-
    % have fun bro


% --- ALGO ---
% generate one valid successor node, skipping already seen states
getNextState([State, _, Steps, _, _], Open, Closed, [Next, State, NewSteps, NewSurvivorScore, NewSearchScore]) :-
    move(State, Next),
    calculateH(Next, NewSurvivorScore),
    NewSteps is Steps + 1,
    NewSearchScore is NewSurvivorScore,                                       % greedy: SearchScore = SurvivorScore only (ignore Steps)
    \+ member([Next, _, _, _, _], Open),
    \+ member([Next, _, _, _, _], Closed).

getAllValidChildren(Node, Open, Closed, Children) :-
    findall(Next, getNextState(Node, Open, Closed, _, Next), Children).

addChildren(Children, Open, NewOpen) :-
    append(Open, Children, NewOpen).

% pick the node with the lowest SearchScore value
getBestNode(Open, Best, Rest) :-
    findMin(Open, Best),
    delete(Open, Best, Rest).
 
findMin([X], X) :- !.
findMin([Head | Tail], Min) :-
    findMin(Tail, TailMin),
    Head    = [_, _, _, _, HeadScore],
    TailMin = [_, _, _, _, TailScore],
    (TailScore < HeadScore -> Min = TailMin ; Min = Head).


% Keeps track of the best solution found so far (most survivors rescued)
search([], _, Best, Best).
search(Open, Closed, BestSoFar, FinalBest) :-
    Open \= [],
    getBestNode(Open, CurrentNode, TmpOpen),
    CurrentNode = [CurrentState, _, _, _, _],
    goal(State), !.
    CurrentState = state(_, _, _, _, SurvivorCount),
 
    % Update best if current node rescued more survivors
    (BestSoFar = none ->
        NewBest = CurrentNode
    ;
        BestSoFar = [BestState, _, _, _, _],
        BestState = state(_, _, _, _, BestCount),
        (SurvivorCount > BestCount -> NewBest = CurrentNode ; NewBest = BestSoFar)
    ),
 
    getAllValidChildren(CurrentNode, TmpOpen, Closed, Children),
    addChildren(Children, TmpOpen, NewOpen),
    append(Closed, [CurrentNode], NewClosed),
    search(NewOpen, NewClosed, NewBest, FinalBest).

solve(Grid) :-
    find_robot(Grid, StartPos),
    InitialState = state(StartPos, Grid, [StartPos], 100, 0),
    calculateH(InitialState, SurvivorScore),
    InitialNode = [InitialState, nil, 0, SurvivorScore, SurvivorScore],
    search([InitialNode], [], none, Best),
    (Best = none ->write("No path found.");print_solution(Best)).

% print result
print_solution([state(_, _, Path, Battery, SCount), _, Steps, _, _]) :-
    reverse(Path, FinalPath),
    write('Path: '), write(FinalPath), nl,
    write('Steps: '), write(Steps), nl,
    write('Survivors rescued: '), write(SCount), nl,
    write('Battery left: '), write(Battery), write('%'), nl.

% goal state: robot is on a survivor cell
goal(state((R, C), Grid, _, _, _)) :-
    get_cell(Grid, (R, C), s).
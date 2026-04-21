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

calculateH(state((R,C),_,_,_,_), H) :-
    heuristic((R,C), H). % waiting for you Ahmed

move(state((R, C), Grid, Path, Battery, S),
     state((NR, NC), Grid, [(NR, NC)|Path], NewBattery, NewS)) :-

    adjacent((R, C), (NR, NC)),
    in_bounds((NR, NC), Grid),
    \+ member((NR, NC), Path),

    get_cell(Grid, (NR, NC), Content),
    Content \= d,
    Content \= f,

    NewBattery is Battery - 10,
    NewBattery > 0,

    (Content = s -> NewS is S + 1 ; NewS is S).

% find the starting position of the robot
find_robot(Grid, (R, C)) :-
    nth1(R, Grid, Row),
    nth1(C, Row, r).

% Print the result
print_solution([state(_,_,Path,_,S),_,_,_,_]) :-
    reverse(Path, FinalPath),
    length(FinalPath, Len),
    Steps is Len - 1,
    write('Path: '), write(FinalPath), nl,
    write('Steps: '), write(Steps), nl,
    write('Survivors rescued: '), write(S), nl.

% goal state: robot is on a survivor cell
goal(state((R, C), Grid, _, _)) :-
    get_cell(Grid, (R, C), s).

% generate all valid next states (children)
expand(State, Children) :-
    % "Children" means all possible states we can reach in ONE move
    % from the current state.
    % findall tries every possible move/2 and collects all valid results.
    findall(NextState, move(State, NextState), Children).

% check if position already visited (closed list)
visited(state(Pos, _, _, _), Closed) :-
    member(Pos, Closed).

% Implementation of step 3 to get the next states
getAllValidChildren(Node, Open, Closed, Goal, Children):-
    findall(Next, getNextState(Node,Open,Closed,Goal,Next),
    Children).

search(Open, Closed, BestSoFar, FinalBest):-
    Open \= [],

    getBestState(Open, CurrentNode, TmpOpen),
    CurrentNode = [State,Parent,G,H,F],

    State = state(_,_,_,_,SCount),

    % Update best solution
    (BestSoFar = none -> NewBest = CurrentNode;
        BestSoFar = [BestState,_,_,_,_],
        BestState = state(_,_,_,_,BestS),
        (SCount > BestS -> NewBest = CurrentNode ; NewBest = BestSoFar)
    ),

    getAllValidChildren(CurrentNode, TmpOpen, Closed, _, Children),
    addChildren(Children, TmpOpen, NewOpen),
    append(Closed, [CurrentNode], NewClosed),

    search(NewOpen, NewClosed, NewBest, FinalBest).

% stop condition
search([], _, Best, Best).

getNextState([State,_,G,_,_],Open,Closed,_,[Next,State,NewG,NewH,NewF]):-
    move(State, Next),
    calculateH(Next, NewH),
    NewG is G + 1,
    NewF is NewH,
    not(member([Next,_,_,_,_], Open)),
    not(member([Next,_,_,_,_], Closed)).

% Implementation of addChildren and getBestState
addChildren(Children, Open, NewOpen):-
    append(Open, Children, NewOpen).

getBestState(Open, BestChild, Rest):-
    findMin(Open, BestChild),
    delete(Open, BestChild, Rest).

    % Implementation of findMin in getBestState determines the search
    alg.

% Greedy best-first search
findMin([X], X):- !.
findMin([Head|T], Min):-
    findMin(T, TmpMin),
    Head = [_,_,_,HeadH,HeadF],
    TmpMin = [_,_,_,TmpH,TmpF],
    (TmpH < HeadH -> Min = TmpMin ; Min = Head).

start(Grid) :-
    find_robot(Grid, StartPos),
    InitialState = state(StartPos, Grid, [StartPos], 100, 0),
    calculateH(InitialState, H),
    Open = [[InitialState, nil, 0, H, H]],
    search(Open, [], none, Best),
    print_solution(Best).
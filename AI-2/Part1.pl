% state representation: state(Position_in_grid, Grid, Path, Battery)

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
move(state((R, C), Grid, Path, Battery),
     state((NR, NC), Grid, [(NR, NC)|Path], NewBattery)) :-

    adjacent((R, C), (NR, NC)),          % try moving in one direction
    in_bounds((NR, NC), Grid),           % make sure it's inside the grid
    \+ member((NR, NC), Path),           % don't go back to a cell in the same path

    get_cell(Grid, (NR, NC), Content),
    Content \= d,                        % can't go into debris
    Content \= f,                        % can't go into fire

    NewBattery is Battery - 10,          % each move costs 10% battery
    NewBattery >= 0.                      % must still have battery left

% find the starting position of the robot
find_robot(Grid, (R, C)) :-
    nth1(R, Grid, Row),
    nth1(C, Row, r).

% print_path
print_path([]).

print_path([(R, C)]) :-
    write('('), write(R), write(','), write(C), write(')').

print_path([(R, C) | Rest]) :-
    write('('), write(R), write(','), write(C), write(')'),
    write(' -> '),
    print_path(Rest).
% print result
print_solution(state(_, _, Path, Battery)) :-
    reverse(Path, FinalPath),
    length(FinalPath, Len),
    Steps is Len - 1,
    write('Path found: '),
    print_path(FinalPath), nl,
    write('Number of steps: '), write(Steps), nl,
    write('Remaining Battery: '), write(Battery), write('%'), nl.

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

% BFS entry point
bfs(StartState, Solution) :-
    % Open list starts with only the start state
    % Closed list is empty at the beginning
    bfs_queue([StartState], [], Solution).

% failure: nothing left to explore
bfs_queue([], _, _) :-
    write('No path found'), nl, !, fail.

% success: first time we reach a survivor
% because BFS explores level by level, this is the nearest one
bfs_queue([Current | _], _, Current) :-
    goal(Current), !.

% main BFS step
% bfs_queue(OpenList, ClosedList, Solution)
bfs_queue([Current | RestQueue], Closed, Solution) :-

    % open list: [Current | RestQueue]
    % Current is the node we are exploring now
    % RestQueue is the rest of the nodes that will be explored after
    % closed list : Closed

    Current = state(Pos, _, _, _),
    % If we already visited this position before, skip it and move to the next node in the queue
    ( member(Pos, Closed) -> bfs_queue(RestQueue, Closed, Solution)
    % Otherwise:
    ;
        
        % generate all possible next states from Current
        expand(Current, Children),

        % add them to the END of the queue
        append(RestQueue, Children, NewQueue),

        % add current position to Closed list
        % Closed list = all positions we have already explored
        bfs_queue(NewQueue, [Pos | Closed], Solution)
    ).

% main solve predicates
% this takes grid as input and was used to test at runtime
solve(Grid) :-
    find_robot(Grid, StartPos),

    % Initial state:
    % Position = robot location
    % Path = starts with only the robot position
    % Battery = 100%
    StartState = state(StartPos, Grid, [StartPos], 100),

    (bfs(StartState, Solution) -> print_solution(Solution) ; true ), !.
% this predicate is for solving grids that are facts in this code which is the one required
solve :-
    grid(Grid),
    solve(Grid).
% some grid examples
grid([
    [r, e, e, d, s],
    [e, f, d, e, e],
    [e, e, d, f, e],
    [d, e, e, f, e],
    [e, d, e, e, e]
]).
grid([
    [e, e, e, e, s],
    [e, d, d, d, e],
    [e, d, r, d, e],
    [e, d, e, d, e],
    [e, e, e, e, e]
]).
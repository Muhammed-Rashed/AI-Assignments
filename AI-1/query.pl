% Mohamed Rashid : 20230335 - Ahmed Ayman : 20230008 - Ali Omar : 20230241 - Abdelrahman Akram : 20230204

% helper predicates %

is_member(Element, [Element|T]).
is_member(Element, [_|T]) :-
    is_member(Element, T).

get_length([], 0).
get_length([H|T], Length) :-
    get_length(T, Temp),
    Length is Temp + 1.

new_append([], List2, List2).
new_append([H|T], List2, [H|Result]) :-
    new_append(T, List2, Result).

new_count(_, [], 0).
new_count(Element, [Element|T], Count) :-
    new_count(Element, T, Temp),
    Count is Temp + 1.
new_count(Element, [H|T], Count) :-
    Element \= H,
    new_count(Element, T, Count).

collect_all_topics_of_books([], Acc, Acc).
collect_all_topics_of_books([Book|Rest], Acc, AllTopics) :-
    topics(Book, BookTopics),
    new_append(BookTopics, Acc, NewAcc),
    collect_all_topics_of_books(Rest, NewAcc, AllTopics).

%% Task 1 %%
books_borrowed_by_student(Student, L):-
    %% wrapper to collect books
    collect_books(Student, [], L), !.


collect_books(Student, Acc, L) :-
    % bring current borrowed book
    borrowed(Student, Book),

    % make sure book is not in the list already
    \+ is_member(Book, Acc),

    % add book to Accumulator list then backtrack
    collect_books(Student, [Book|Acc], L).
% now Acc has the full list of borrowed books so we make the last argument which is the result equal to it
collect_books(_, L, L).

%% Task 2 %%
borrowers_count(Book, N) :-
    % build a list of borrowers then count them
    build_borrowers_list(Book, [], List), !,
    get_length(List, N).

build_borrowers_list(Book, Acc, List) :-
    % get a Student that borrowed Book
    borrowed(Student, Book),

    % only add Student that are not in Accumulator list yet
    \+ is_member(Student, Acc),

    % add the Student
    build_borrowers_list(Book, [Student|Acc], List).
% stop after adding all Students that borrowed Book
build_borrowers_list(_, List, List).

%% Task 3 %%
most_borrowed_book(B) :-
    build_books_list([], Books),
    Books = [H|T],
    get_most_borrowed(H, T, B), !.

get_most_borrowed(MostBorrowed, [], MostBorrowed).
get_most_borrowed(MostBorrowed, [H|T], B) :-
    more_borrowed(MostBorrowed, H, NewMostBorrowed),
    get_most_borrowed(NewMostBorrowed, T, B).

more_borrowed(Book1, Book2, Most_borrowed_book) :-
    % get borrowers count for both Books
    borrowers_count(Book1, N),
    borrowers_count(Book2, M),

    % make Most_borrowed_Book equal the book with the highest borrowers count
    (N > M -> Most_borrowed_book = Book1 ; Most_borrowed_book = Book2).

build_books_list(Acc, L) :-
    % bring current borrowed book
    book(Book, _),

    % make sure book is not in the list already
    \+ is_member(Book, Acc),

    % add book to Accumulator list then backtrack
    build_books_list([Book|Acc], L).
build_books_list(L, L).

%% Task 4 %%
ratings_of_book(Book, L) :-
    collect_ratings(Book, [], L), !.
    
collect_ratings(Book, Acc, L) :-
    rating(Student, Book, Score),
    \+ is_member((Student, Score), Acc),
    collect_ratings(Book, [(Student, Score)|Acc], L).

collect_ratings(_, L, L).


%% Task 5 %%
top_reviewer(Student):-
    % take a score
    rating(Student, _, Score),

    % make sure no other score in the system is higher than the current score
    \+(higher_score_than(Score)), !.

higher_score_than(Score):-
    % take another score from the library data
    rating(_, _, OtherScore),

    % check if the score is higher than the current score
    Score < OtherScore.

%% Task 6 %%

most_common_topic_for_student(Student, Topic):-
    % get all books borrowed by the student
    books_borrowed_by_student(Student, Books),

    % collect all topics from these books and merge them into one list
    collect_all_topics_of_books(Books, [], AllTopics),

    is_member(Topic, AllTopics),
    new_count(Topic, AllTopics, Count),
    \+ higher_topic_count(Count, AllTopics), !.

higher_topic_count(Count, Topics):-
    is_member(OtherTopic, Topics),
    new_count(OtherTopic, Topics, OtherCount),
    OtherCount > Count.

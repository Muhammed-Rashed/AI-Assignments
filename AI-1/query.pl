% Mohamed Rashid : 20230335
% Ahmed Ayman : 20230008 
% Ali Omar : 20230241 
% Abdelrahman Akram : 20230204

%%%% helper predicates %%%%

% check if an element exists in a list
is_member(Element, [Element|T]).
is_member(Element, [_|T]) :-
    is_member(Element, T).

% get the length of a list
get_length([], 0).
get_length([H|T], Length) :-
    get_length(T, Temp),
    Length is Temp + 1.

% append two lists together
new_append([], List2, List2).
new_append([H|T], List2, [H|Result]) :-
    new_append(T, List2, Result).

% count how many times an element appears in a list
new_count(_, [], 0).
new_count(Element, [Element|T], Count) :-
    new_count(Element, T, Temp),
    Count is Temp + 1.
new_count(Element, [H|T], Count) :-
    Element \= H,
    new_count(Element, T, Count).

% collect all topics from a list of books into one list
collect_all_topics_of_books([], Acc, Acc).
collect_all_topics_of_books([Book|Rest], Acc, AllTopics) :-
    topics(Book, BookTopics),
    new_append(BookTopics, Acc, NewAcc),
    collect_all_topics_of_books(Rest, NewAcc, AllTopics).

%%%% Task 1 %%%%

% books_borrowed_by_student(Student, L)
% gives the list of books borrowed by a specific student
books_borrowed_by_student(Student, L):-
    %% wrapper to collect books
    collect_books(Student, [], L), !.

collect_books(Student, Acc, L) :-
    % bring current borrowed book
    borrowed(Student, Book),

    % make sure book is not in the list already
    \+ is_member(Book, Acc),

    % add book to Accumulator list then backtrack to find more
    collect_books(Student, [Book|Acc], L).

% now Acc has the full list of borrowed books so we make the last argument which is the result equal to it
collect_books(_, L, L).

%%%% Task 2 %%%%

% borrowers_count(Book, N)
% returns the number of students who borrowed a given book
borrowers_count(Book, N) :-
    % build a list of borrowers then count them
    build_borrowers_list(Book, [], List), !,
    get_length(List, N).

build_borrowers_list(Book, Acc, List) :-
    % get a Student that borrowed Book
    borrowed(Student, Book),

    % only add Student that are not in Accumulator list yet
    \+ is_member(Student, Acc),

    % add the Student to the list
    build_borrowers_list(Book, [Student|Acc], List).

% stop after adding all Students that borrowed Book
build_borrowers_list(_, List, List).

%%%% Task 3 %%%%

% most_borrowed_book(Book)
% finds the book that has the highest number of borrowers
most_borrowed_book(B):-
    % take a book from the data
    book(B, _),

    % make sure no other book in the data is more borrowed than current book
    \+(more_borrowed(B)), !.

more_borrowed(Book1):-
    % take another book from the library data
    book(Book2, _),
    Book2 \= Book1,

    % get the borrowers count for each book
    borrowers_count(Book1, N),
    borrowers_count(Book2, M),

    % check if the borrower count for Book2 is higher than borrower count of Book1
    N < M.

%%%% Task 4 %%%%

% ratings_of_book(Book, L)
% returns a list of students and their ratings for a specific book
ratings_of_book(Book, L) :-
    collect_ratings(Book, [], L), !.
    
collect_ratings(Book, Acc, L) :-
    % get rating for the book
    rating(Student, Book, Score),

    % make sure we do not add the same pair twice
    \+ is_member((Student, Score), Acc),

    % add the pair (Student, Score)
    collect_ratings(Book, [(Student, Score)|Acc], L).

collect_ratings(_, L, L).

%%%% Task 5 %%%%

% top_reviewer(Student)
% returns the student who gave the highest rating to any book
top_reviewer(Student):-
    % take a score from the rating facts
    rating(Student, _, Score),

    % make sure no other score is higher than the current score
    \+(higher_score_than(Score)), !.

higher_score_than(Score):-
    % take another score from the library data
    rating(_, _, OtherScore),

    % check if the score is higher than the current score
    Score < OtherScore.

%%%% Task 6 %%%%

% most_common_topic_for_student(Student, Topic)
% finds the topic that appears most in books borrowed by the student
most_common_topic_for_student(Student, Topic):-

    % get all books borrowed by the student
    books_borrowed_by_student(Student, Books),

    % collect all topics from these books and merge them into one list
    collect_all_topics_of_books(Books, [], AllTopics),

    % pick a topic from the collected list
    is_member(Topic, AllTopics),

    % count how many times this topic appears
    new_count(Topic, AllTopics, Count),

    % make sure no other topic appears more times
    \+ higher_topic_count(Count, AllTopics), !.

higher_topic_count(Count, Topics):-
    % check another topic from the list
    is_member(OtherTopic, Topics),

    % count its occurrences
    new_count(OtherTopic, Topics, OtherCount),

    % see if it appears more times
    OtherCount > Count.
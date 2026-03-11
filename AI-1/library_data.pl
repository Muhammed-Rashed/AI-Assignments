%%%%%%%%%%%%%%%%%%%%%%%%%%%% Students Info %%%%%%%%%%%%%%%%%%%%%%%%%%%%
% student(Name, Year)

student(ali, first).
student(sara, second).
student(omar, third).
student(mona, second).
student(yousef, first).
student(nour, fourth).
student(karim, third).

%%%%%%%%%%%%%%%%%%%%%%%%%%%% Books Info %%%%%%%%%%%%%%%%%%%%%%%%%%%%
% book(Title, Author)

book(prolog_fundamentals, dr_hassan).
book(recursion_in_depth, dr_sara).
book(list_programming, dr_ahmed).
book(ai_intro, dr_mona).

%%%%%%%%%%%%%%%%%%%%%%%%%%%% Borrow Info %%%%%%%%%%%%%%%%%%%%%%%%%%%%
% borrowed(Student, Book)

borrowed(ali, prolog_fundamentals).
borrowed(ali, list_programming).

borrowed(sara, recursion_in_depth).
borrowed(sara, ai_intro).

borrowed(omar, recursion_in_depth).

borrowed(mona, prolog_fundamentals).
borrowed(mona, recursion_in_depth).
borrowed(mona, list_programming).

borrowed(yousef, list_programming).

borrowed(nour, ai_intro).

borrowed(karim, recursion_in_depth).

%%%%%%%%%%%%%%%%%%%%%%%%%%%% Topics Info %%%%%%%%%%%%%%%%%%%%%%%%%%%%
% topics(Book, TopicsList)

topics(prolog_fundamentals, [facts, rules, queries, unification]).
topics(recursion_in_depth, [base_case, recursive_case, tracing, termination]).
topics(list_programming, [head_tail, member, append, length, prefix, suffix]).
topics(ai_intro, [search, logic, knowledge_representation]).

%%%%%%%%%%%%%%%%%%%%%%%%%%%% Ratings Info %%%%%%%%%%%%%%%%%%%%%%%%%%%%
% rating(Student, Book, Score)

rating(ali, prolog_fundamentals, 85).
rating(ali, list_programming, 90).

rating(sara, recursion_in_depth, 95).
rating(sara, ai_intro, 88).

rating(omar, recursion_in_depth, 80).

rating(mona, prolog_fundamentals, 92).
rating(mona, recursion_in_depth, 89).
rating(mona, list_programming, 91).

rating(yousef, list_programming, 60).

rating(nour, ai_intro, 78).

rating(karim, recursion_in_depth, 83).


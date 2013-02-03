G'n'T Eval
==========

G'n'T Eval is an evaluation suite that allows to carry out pen and paper
evaluations. It ships with all necessary tools, i.e. management tools, form
creation and printing as well as scanning and creating aggregated results.

Basically it works like this:

![Form printed sheet to aggregated results](http://b.uni-hd.de/gnt-eval/transform.png)

The tool is tailored towards university style teaching, i.e. professors giving
lectures, tutors holding study groups for that lecture and students attending
both. It is currently used to carry out the evaluation of the maths, physics,
computer science and astronomy faculties at the university in Heidelberg. About
2000 questionnaires are processed each term (that number is limited by manpower,
not by software).


Trying it out
-------------

If you want to try the software it is recommended to download a VirtualBox Image
that has G'n'T Eval preinstalled. It works out of the box and you can simply point
your web browser (not the VirtualBox one) to <http://localhost:3000> after
starting the image.

[Download VirtualBox Image](http://b.uni-hd.de/gnt-eval/virtualboximg.html)

More information may be found in `doc/VIRTUAL_BOX_IMAGE`


I need help
-----------

If you are stuck anywhere or have questions about the project feel free to [open a
ticket](https://github.com/breunigs/gnt-eval/issues/new) or write an email to
<breunig@uni-hd.de>.

You can have a look at the files in the `doc` directory of the project, where most
of the end-user documentation resides. If this is your first evaluation ever,
reading `doc/MY_FIRST_EVAL` is highly recommended. Apart from that, I have two
suggestions:

- Start small. Only involve people that are forgiving if it doesn’t work out
immediately.
- Ranking doesn’t help anyone get better at anything. Finding out why
someone rules (or sucks) is much more helpful than knowing that she/he does,
because you can improve on where you’re lacking. You can’t improve on being #42.


Installation
------------

The installation will take a while due to the large number of dependencies
required. If you want to carry it out, you can find details in `doc/INSTALL`.


Contribution
------------

Please do! If you have suggestions, patches or simply want to report bugs please
either [open a ticket](https://github.com/breunigs/gnt-eval/issues/new) or write
an email to <breunig@uni-hd.de>.

For starters, the project is split up into interconnected parts:

- Web GUI is located in `web/` and hosts many files used by other parts of the
project. It is also known as _seee_. Many configuration options may be found in
`web/config/seee_config.rb`. The web GUI is used for operations that apply to a
single lecture, professor, etc.
- Operations that work on many things at once are handled in the `Rakefile` (split
into parts in `rakefiles/*`)
- the optical mark recognition is located in `pest/`.
- The actual tex class rendering the questionnaires may be found in
`tex/sheets/tex/latex/eval/eval.cls`. The directory structure is required by TeX.
- The result.pdf generation is distributed across many files. A good starting
point is `web/app/lib/AbstractForm.rb`. The visualizers for different question
types are located in `tex/results`. There’s also a readme there that should get
you started.
- If you’re looking for something specific but can’t find it, please
[open a ticket](https://github.com/breunigs/gnt-eval/issues/new)


License
-------

The project is licensed under the permissive [ISC
license](https://en.wikipedia.org/wiki/ISC_license). Dependencies of course remain
under their own respective licenses. You can find details about those in
doc/ATTRIBUTION. If there are any issues please open a ticket.


About
-----

G'n'T Eval started as Rails project to manage the lectures that should be
evaluated but has grown to offer the full stack required to carry out evaluations.
While many of the components had names already, the project as a whole didn’t. The
parts are listed in order of creation:

- **WebGUI:** Seee for _Siehe, es erleichtert Evaluation_ or _see, it simplifies
evaluation_. _See_ is German for _lake_ and the name was chosen because all
projects of [Fachschaft MathPhys](http://mathphys.fsk.uni-heidelberg.de/) refered
to bodies of water at that time.
- **Optical Mark Recognition:** Pest for _Practival Evaluation ScripT_. _Pest_ is
German for the _Black Death_.
- **TeX form generation:** Its name is actually Cholera, but it never established. I
can’t remember the meaning of the acronym.

Keeping true to the obscure acronym naming as explained in [PhD Comic’s Clever
Acronyms](http://www.phdcomics.com/comics.php?f=1100) we came up with the project
name:


            .-""-.             G'n'T-Eval
      ⑊    /      \
      │⑊~~~~~~~│   ;           G as in Evaluation
      │ ⑊      │  /            T as in Excellence
      │  ⑊     │-'             and n as in and.
      │   ⑊    │
      │    ⑊   │
      │     ⑊  │
      │      ⑊ │
      │       ⑊│
      └────────┘

Excellence is a reference to the [German Universities Excellence
Initiative](https://en.wikipedia.org/wiki/German_Universities_Excellence_Initiative)

The following people have contributed and are therefore lovingly called _daft_ by
the project (in German, alphabetical order):

- Jasper ist doof
– Moritz ist doof
- Oliver ist doof
- Paul ist doof
- Rebecca ist doof
- Stefan ist doof

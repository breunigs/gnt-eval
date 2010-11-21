/* -- THIS FILE IS GENERATED - DO NOT EDIT *//* -*- Mode: C; c-basic-offset: 4 -*- */

#include <Python.h>



#line 3 "./pygtk/zbarpygtk.override"
#include <Python.h>
#include <pygobject.h>
#include <zbar/zbargtk.h>
#line 12 "pygtk/zbarpygtk.c"


/* ---------- types from other modules ---------- */
static PyTypeObject *_PyGtkWidget_Type;
#define PyGtkWidget_Type (*_PyGtkWidget_Type)
static PyTypeObject *_PyGdkPixbuf_Type;
#define PyGdkPixbuf_Type (*_PyGdkPixbuf_Type)


/* ---------- forward type declarations ---------- */
PyTypeObject G_GNUC_INTERNAL PyZBarGtk_Type;

#line 25 "pygtk/zbarpygtk.c"



/* ----------- ZBarGtk ----------- */

static PyObject *
_wrap_zbar_gtk_scan_image(PyGObject *self, PyObject *args, PyObject *kwargs)
{
    static char *kwlist[] = { "image", NULL };
    PyGObject *image;

    if (!PyArg_ParseTupleAndKeywords(args, kwargs,"O!:ZBar.Gtk.scan_image", kwlist, &PyGdkPixbuf_Type, &image))
        return NULL;
    
    zbar_gtk_scan_image(ZBAR_GTK(self->obj), GDK_PIXBUF(image->obj));
    
    Py_INCREF(Py_None);
    return Py_None;
}

static PyObject *
_wrap_zbar_gtk_get_video_device(PyGObject *self)
{
    const gchar *ret;

    
    ret = zbar_gtk_get_video_device(ZBAR_GTK(self->obj));
    
    if (ret)
        return PyString_FromString(ret);
    Py_INCREF(Py_None);
    return Py_None;
}

static PyObject *
_wrap_zbar_gtk_set_video_device(PyGObject *self, PyObject *args, PyObject *kwargs)
{
    static char *kwlist[] = { "video_device", NULL };
    char *video_device;

    if (!PyArg_ParseTupleAndKeywords(args, kwargs,"s:ZBar.Gtk.set_video_device", kwlist, &video_device))
        return NULL;
    
    zbar_gtk_set_video_device(ZBAR_GTK(self->obj), video_device);
    
    Py_INCREF(Py_None);
    return Py_None;
}

static PyObject *
_wrap_zbar_gtk_get_video_enabled(PyGObject *self)
{
    int ret;

    
    ret = zbar_gtk_get_video_enabled(ZBAR_GTK(self->obj));
    
    return PyBool_FromLong(ret);

}

static PyObject *
_wrap_zbar_gtk_set_video_enabled(PyGObject *self, PyObject *args, PyObject *kwargs)
{
    static char *kwlist[] = { "video_enabled", NULL };
    int video_enabled;

    if (!PyArg_ParseTupleAndKeywords(args, kwargs,"i:ZBar.Gtk.set_video_enabled", kwlist, &video_enabled))
        return NULL;
    
    zbar_gtk_set_video_enabled(ZBAR_GTK(self->obj), video_enabled);
    
    Py_INCREF(Py_None);
    return Py_None;
}

static PyObject *
_wrap_zbar_gtk_get_video_opened(PyGObject *self)
{
    int ret;

    
    ret = zbar_gtk_get_video_opened(ZBAR_GTK(self->obj));
    
    return PyBool_FromLong(ret);

}

static const PyMethodDef _PyZBarGtk_methods[] = {
    { "scan_image", (PyCFunction)_wrap_zbar_gtk_scan_image, METH_VARARGS|METH_KEYWORDS,
      NULL },
    { "get_video_device", (PyCFunction)_wrap_zbar_gtk_get_video_device, METH_NOARGS,
      NULL },
    { "set_video_device", (PyCFunction)_wrap_zbar_gtk_set_video_device, METH_VARARGS|METH_KEYWORDS,
      NULL },
    { "get_video_enabled", (PyCFunction)_wrap_zbar_gtk_get_video_enabled, METH_NOARGS,
      NULL },
    { "set_video_enabled", (PyCFunction)_wrap_zbar_gtk_set_video_enabled, METH_VARARGS|METH_KEYWORDS,
      NULL },
    { "get_video_opened", (PyCFunction)_wrap_zbar_gtk_get_video_opened, METH_NOARGS,
      NULL },
    { NULL, NULL, 0, NULL }
};

PyTypeObject G_GNUC_INTERNAL PyZBarGtk_Type = {
    PyObject_HEAD_INIT(NULL)
    0,                                 /* ob_size */
    "zbarpygtk.Gtk",                   /* tp_name */
    sizeof(PyGObject),          /* tp_basicsize */
    0,                                 /* tp_itemsize */
    /* methods */
    (destructor)0,        /* tp_dealloc */
    (printfunc)0,                      /* tp_print */
    (getattrfunc)0,       /* tp_getattr */
    (setattrfunc)0,       /* tp_setattr */
    (cmpfunc)0,           /* tp_compare */
    (reprfunc)0,             /* tp_repr */
    (PyNumberMethods*)0,     /* tp_as_number */
    (PySequenceMethods*)0, /* tp_as_sequence */
    (PyMappingMethods*)0,   /* tp_as_mapping */
    (hashfunc)0,             /* tp_hash */
    (ternaryfunc)0,          /* tp_call */
    (reprfunc)0,              /* tp_str */
    (getattrofunc)0,     /* tp_getattro */
    (setattrofunc)0,     /* tp_setattro */
    (PyBufferProcs*)0,  /* tp_as_buffer */
    Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE,                      /* tp_flags */
    NULL,                        /* Documentation string */
    (traverseproc)0,     /* tp_traverse */
    (inquiry)0,             /* tp_clear */
    (richcmpfunc)0,   /* tp_richcompare */
    offsetof(PyGObject, weakreflist),             /* tp_weaklistoffset */
    (getiterfunc)0,          /* tp_iter */
    (iternextfunc)0,     /* tp_iternext */
    (struct PyMethodDef*)_PyZBarGtk_methods, /* tp_methods */
    (struct PyMemberDef*)0,              /* tp_members */
    (struct PyGetSetDef*)0,  /* tp_getset */
    NULL,                              /* tp_base */
    NULL,                              /* tp_dict */
    (descrgetfunc)0,    /* tp_descr_get */
    (descrsetfunc)0,    /* tp_descr_set */
    offsetof(PyGObject, inst_dict),                 /* tp_dictoffset */
    (initproc)0,             /* tp_init */
    (allocfunc)0,           /* tp_alloc */
    (newfunc)0,               /* tp_new */
    (freefunc)0,             /* tp_free */
    (inquiry)0              /* tp_is_gc */
};



/* ----------- functions ----------- */

const PyMethodDef zbarpygtk_functions[] = {
    { NULL, NULL, 0, NULL }
};

/* initialise stuff extension classes */
void
zbarpygtk_register_classes(PyObject *d)
{
    PyObject *module;

    if ((module = PyImport_ImportModule("gtk")) != NULL) {
        _PyGtkWidget_Type = (PyTypeObject *)PyObject_GetAttrString(module, "Widget");
        if (_PyGtkWidget_Type == NULL) {
            PyErr_SetString(PyExc_ImportError,
                "cannot import name Widget from gtk");
            return ;
        }
    } else {
        PyErr_SetString(PyExc_ImportError,
            "could not import gtk");
        return ;
    }
    if ((module = PyImport_ImportModule("gtk.gdk")) != NULL) {
        _PyGdkPixbuf_Type = (PyTypeObject *)PyObject_GetAttrString(module, "Pixbuf");
        if (_PyGdkPixbuf_Type == NULL) {
            PyErr_SetString(PyExc_ImportError,
                "cannot import name Pixbuf from gtk.gdk");
            return ;
        }
    } else {
        PyErr_SetString(PyExc_ImportError,
            "could not import gtk.gdk");
        return ;
    }


#line 215 "pygtk/zbarpygtk.c"
    pygobject_register_class(d, "ZBarGtk", ZBAR_TYPE_GTK, &PyZBarGtk_Type, Py_BuildValue("(O)", &PyGtkWidget_Type));
}

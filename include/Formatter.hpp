/*
 * Copyright (c) 2020-2024 BedRock Systems, Inc.
 * This software is distributed under the terms of the BedRock Open-Source License.
 * See the LICENSE-BedRock file in the repository root for details.
 */
#pragma once

#include "llvm/ADT/APSInt.h"
#include "llvm/ADT/StringRef.h"
#include "llvm/Support/raw_ostream.h"
#include <string.h>

namespace fmt {

class Formatter {
private:
    llvm::raw_ostream& out;
    unsigned int depth;
    unsigned int spaces;
    bool blank;

public:
    explicit Formatter();
    explicit Formatter(llvm::raw_ostream&);

    llvm::raw_ostream& line();

    llvm::raw_ostream& nobreak();

    llvm::raw_ostream& flush();

    void nbsp();

    void indent();
    void outdent();

    void ascii(int c);

    template<typename T>
    Formatter& operator<<(T val) {
        nobreak() << val;
        blank = false;
        return *this;
    }

public:
    // debugging
    unsigned int get_depth() const {
        return depth;
    }

public:
    static Formatter default_output;
};

struct NBSP;
extern const NBSP* nbsp;

Formatter& operator<<(Formatter& out, const llvm::APSInt&);

Formatter& operator<<(Formatter& out, const NBSP* _);

struct INDENT;
extern const INDENT* indent;
Formatter& operator<<(Formatter& out, const INDENT* _);

struct OUTDENT;
extern const OUTDENT* outdent;
Formatter& operator<<(Formatter& out, const OUTDENT* _);

struct LPAREN;
extern const LPAREN* lparen;
Formatter& operator<<(Formatter& out, const LPAREN* _);

struct RPAREN;
extern const RPAREN* rparen;
Formatter& operator<<(Formatter& out, const RPAREN* _);

struct LINE;
extern const LINE* line;
Formatter& operator<<(Formatter& out, const LINE* _);

struct TUPLESEP;
extern const TUPLESEP* tuple_sep;
Formatter& operator<<(Formatter&, const TUPLESEP*);

struct CONS;
extern const CONS* cons;
Formatter& operator<<(Formatter&, const CONS*);

struct BOOL {
    bool value;
    explicit BOOL(bool b) : value(b) {}
};
Formatter& operator<<(Formatter& out, BOOL b);

}

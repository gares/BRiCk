#include "clang/AST/Stmt.h"
#include "clang/AST/Decl.h"

void declToCoq(clang::ASTContext *ctxt, const clang::Decl *decl);

void stmtToCoq(clang::ASTContext *ctxt, const clang::Stmt *stmt);

void toCoqModule(clang::ASTContext *ctxt, const clang::TranslationUnitDecl *decl);

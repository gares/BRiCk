/*
 * Copyright (C) BedRock Systems Inc. 2019 Gregory Malecha
 *
 * SPDX-License-Identifier:AGPL-3.0-or-later
 */
#pragma once
#include <utility>
#include <map>

#include "clang/AST/Decl.h"
#include "Formatter.hpp"
#include "ModuleBuilder.hpp"

class SpecCollector {
public:
	SpecCollector() {}

	void add_specification(const clang::NamedDecl* decl, RawComment *ref, ASTContext& context) {
		ref->setAttached();
		this->comment_decl_.insert(std::make_pair(ref, decl));
		if (auto comment = context.getCommentForDecl(decl, nullptr)) {
			this->specifications_.push_back(std::make_pair(decl, comment));
		}
	}

	std::list<std::pair<const clang::NamedDecl*, comments::FullComment*> >::const_iterator
	begin() const {
		return this->specifications_.begin();
	}

	std::list<std::pair<const clang::NamedDecl*, comments::FullComment*> >::const_iterator
	end() const {
		return this->specifications_.end();
	}

	llvm::Optional<const NamedDecl*> decl_for_comment(RawComment* cmt) const {
		auto result = comment_decl_.find(cmt);
		if (result == comment_decl_.end()) {
			return {};
		}
		return result->second;
	}

private:
	std::list<std::pair<const clang::NamedDecl*, comments::FullComment*> > specifications_;
  std::map<RawComment*,const NamedDecl*> comment_decl_;
};

void
write_spec(::Module* mod, const SpecCollector &specs, const clang::TranslationUnitDecl* tu, Filter& filter, fmt::Formatter& output);
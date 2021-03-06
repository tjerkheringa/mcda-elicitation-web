/*
 * Copyright 2013 the original author or authors.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package org.drugis.mcdaweb.standalone.controllers;

import java.security.Principal;

import javax.inject.Inject;
import javax.inject.Provider;
import javax.servlet.http.HttpServletRequest;

import org.drugis.mcdaweb.standalone.account.AccountRepository;
import org.springframework.social.connect.ConnectionRepository;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.RequestMapping;

@Controller
public class IndexController {
	
	private final Provider<ConnectionRepository> connectionRepositoryProvider;
	
	private final AccountRepository accountRepository;

	@Inject
	public IndexController(Provider<ConnectionRepository> connectionRepositoryProvider, AccountRepository accountRepository) {
		this.connectionRepositoryProvider = connectionRepositoryProvider;
		this.accountRepository = accountRepository;
	}

	@RequestMapping("/")
	public String index(Principal currentUser, Model model, HttpServletRequest request) {
		model.addAttribute("connectionsToProviders", getConnectionRepository().findAllConnections());
		try {
			model.addAttribute(accountRepository.findAccountByUsername(currentUser.getName()));
		} catch (org.springframework.dao.EmptyResultDataAccessException e) {
			request.getSession().invalidate();
			return "redirect:/signin";
		}
		return "index";
	}
	
	private ConnectionRepository getConnectionRepository() {
		return connectionRepositoryProvider.get();
	}
}

import React from 'react';
import logo from './logo.svg';
import './App.css';

import { HashRouter } from "react-router-dom";
import { Routes, Route } from "react-router-dom";

import HomePage from "./pages/HomePage";
import About from "./pages/About";

function App() {
  return (
      <HashRouter>
        <Routes>
          <Route path={"/"} element={<HomePage />} />
          <Route path={"/about/"} element={<About />} />
        </Routes>
      </HashRouter>
  );
}

export default App;

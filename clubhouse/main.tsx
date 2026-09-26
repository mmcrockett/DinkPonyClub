import React from "react";
import { createRoot } from "react-dom/client";
import League from "./league";
import "./globals.css";
createRoot(document.getElementById("clubhouse")!).render(<League />);

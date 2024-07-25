import { Link } from "react-router-dom";

function About() {
    return (
        <div>
            Welcome to the About page!
            <Link to={"/"}>
                <div>Home</div>
            </Link>
        </div>
    );
}

export default About;
